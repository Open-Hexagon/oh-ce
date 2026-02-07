#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avassert.h>
#include <libavutil/channel_layout.h>
#include <libavutil/imgutils.h>
#include <libavutil/mathematics.h>
#include <libavutil/opt.h>
#include <libavutil/timestamp.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct OutputStream {
    AVStream* stream;
    AVCodecContext* codec_context;
    AVPacket* packet;
    AVFrame* frame;
    int64_t presentation_timestamp;
} OutputStream;

// globals
static AVFormatContext* format_context;
static OutputStream video;
static OutputStream audio;
static struct SwsContext* sws_context;
static const AVOutputFormat* output_format;
static AVFrame* tmp_audio_frame;
static const char* filename;
struct SwrContext* swr_context;
int64_t samples_count;

// return 0 on success, 1 on failure
int start_encoding(const char* file, const int width, const int height, const int framerate, const int sample_rate) {
    filename = file;
    avformat_alloc_output_context2(&format_context, NULL, NULL, filename);
    if (!format_context) {
        printf("Could not deduce output format from file extension: using matroska.\n");
        avformat_alloc_output_context2(&format_context, NULL, "matroska", filename);
        if(!format_context) {
            // still failed
            fprintf(stderr, "Could not allocate output context.\n");
            return 1;
        }
    }
    output_format = format_context->oformat;
    if (output_format->video_codec == AV_CODEC_ID_NONE) {
        fprintf(stderr, "Output format '%s' has no video codec.\n", output_format->long_name);
        return 1;
    }
    if (output_format->audio_codec == AV_CODEC_ID_NONE) {
        fprintf(stderr, "Output format '%s' has no audio codec.\n", output_format->long_name);
        return 1;
    }

    // ------------- add and open video stream -------------
    // find the encoder
    const AVCodec* video_codec = avcodec_find_encoder(output_format->video_codec);
    if (!video_codec) {
        fprintf(stderr, "Could not find encoder for '%s'\n", avcodec_get_name(output_format->video_codec));
        return 1;
    }
    video.packet = av_packet_alloc();
    if (!video.packet) {
        fprintf(stderr, "Could not allocate AVPacket\n");
        return 1;
    }
    video.stream = avformat_new_stream(format_context, video_codec);
    if (!video.stream) {
        fprintf(stderr, "Could not allocate stream\n");
        return 1;
    }
    video.stream->id = format_context->nb_streams - 1;
    video.codec_context = avcodec_alloc_context3(video_codec);
    if (!video.codec_context) {
        fprintf(stderr, "Could not allocate an encoding contet\n");
        return 1;
    }
    video.codec_context->codec_id = output_format->video_codec;

    // width and height must be a multiple of 2
    video.codec_context->width = width;
    video.codec_context->height = height;

    // timebase = 1/framerate, so timestamp increments will be 1
    video.stream->time_base = (AVRational){1, framerate};
    video.codec_context->time_base = video.stream->time_base;

    // TODO: make customizable
    av_opt_set(video.codec_context->priv_data, "preset", "slow", 0);
    av_opt_set(video.codec_context->priv_data, "crf", "23", 0);

    // TODO: make max bitrate configurable (atm there is no max)

    // make framerate show correctly
    video.stream->avg_frame_rate = (AVRational){framerate, 1};

    // emit one intra frame every 30 frames at most
    video.codec_context->gop_size = 30;

    // pixel format seems to be supported by most codecs
    video.codec_context->pix_fmt = AV_PIX_FMT_YUV420P;

    // some formats want stream headers to be separate
    if (output_format->flags & AVFMT_GLOBALHEADER) {
        video.codec_context->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    // open the codec
    int ret = avcodec_open2(video.codec_context, video_codec, NULL);
    if (ret < 0) {
        fprintf(stderr, "Could not open video codec: %s\n", av_err2str(ret));
        return 1;
    }

    // allocate and init a reusable frame
    video.frame = av_frame_alloc();
    if (!video.frame) {
        fprintf(stderr, "Could not allocate video frame\n");
        return 1;
    }
    video.frame->format = video.codec_context->pix_fmt;
    video.frame->width = width;
    video.frame->height = height;

    // allocate the buffers for the frame data
    ret = av_frame_get_buffer(video.frame, 0);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate video frame data.\n");
        return 1;
    }

    // copy the stream parameters to the muxer
    ret = avcodec_parameters_from_context(video.stream->codecpar, video.codec_context);
    if (ret < 0) {
        fprintf(stderr, "Could not copy the stream parameters\n");
        return 1;
    }

    // initialize sws context for converting color format
    sws_context = sws_getContext(width, height, AV_PIX_FMT_RGBA, width, height, video.codec_context->pix_fmt, SWS_BICUBIC, NULL, NULL, NULL);
    if (!sws_context) {
        fprintf(stderr, "Could not initialize color conversion context\n");
        return 1;
    }

    // start the video at 0
    video.presentation_timestamp = 0;

    // ------------- add and open audio stream -------------
    const AVCodec* audio_codec = avcodec_find_encoder(output_format->audio_codec);
    if (!audio_codec) {
        fprintf(stderr, "Could not find encoder for '%s'\n", avcodec_get_name(output_format->audio_codec));
        return 1;
    }
    audio.packet = av_packet_alloc();
    if (!audio.packet) {
        fprintf(stderr, "Could not allocate AVPacket\n");
        return 1;
    }
    audio.stream = avformat_new_stream(format_context, audio_codec);
    if (!audio.stream) {
        fprintf(stderr, "Could not allocate stream\n");
        return 1;
    }
    audio.stream->id = format_context->nb_streams - 1;
    audio.codec_context = avcodec_alloc_context3(audio_codec);
    if (!audio.codec_context) {
        fprintf(stderr, "Could not allocate an audio encoding context\n");
        return 1;
    }
    const enum AVSampleFormat *sample_fmt = audio_codec->sample_fmts;
    audio.codec_context->sample_fmt = audio_codec->sample_fmts ? audio_codec->sample_fmts[0] : AV_SAMPLE_FMT_FLTP;
    if (!audio_codec->supported_samplerates) {
        fprintf(stderr, "Codec has no supported sample rates.\n");
        return 1;
    }
    const int* p = audio_codec->supported_samplerates;
    int is_supported = 0;
    while (*p) {
        if (*p == sample_rate) {
            is_supported = 1;
        }
        p++;
    }
    if (!is_supported) {
        fprintf(stderr, "Requested sample rate (%iHz) is not supported\n", sample_rate);
        return 1;
    }

    // TODO: make max bitrate configurable (atm there is no max)

    audio.codec_context->sample_rate = sample_rate;
    av_channel_layout_copy(&audio.codec_context->ch_layout, &(AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO);
    audio.stream->time_base = (AVRational){1, sample_rate};

    // Some formats want stream headers to be separate
    if (format_context->flags & AVFMT_GLOBALHEADER) {
        audio.codec_context->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    // open the audio stream
    ret = avcodec_open2(audio.codec_context, audio_codec, NULL);
    if (ret < 0) {
        fprintf(stderr, "Could not open audio codec: %s\n", av_err2str(ret));
        return 1;
    }

    // allocate frame
    audio.frame = av_frame_alloc();
    if (!audio.frame) {
        fprintf(stderr, "Error allocating an audio frame\n");
        return 1;
    }
    audio.frame->format = audio.codec_context->sample_fmt;
    av_channel_layout_copy(&audio.frame->ch_layout, &audio.codec_context->ch_layout);
    audio.frame->sample_rate = audio.codec_context->sample_rate;
    audio.frame->nb_samples = audio.codec_context->frame_size;
    if (audio.codec_context->frame_size) {
        if (av_frame_get_buffer(audio.frame, 0) < 0) {
            fprintf(stderr, "Error allocating an audio buffer\n");
            return 1;
        }
    } else {
        fprintf(stderr, "No samples in audio frame\n");
        return 1;
    }

    // allocate tmp frame
    tmp_audio_frame = av_frame_alloc();
    if (!tmp_audio_frame) {
        fprintf(stderr, "Error allocating an audio frame\n");
        return 1;
    }
    tmp_audio_frame->format = AV_SAMPLE_FMT_S16;
    av_channel_layout_copy(&tmp_audio_frame->ch_layout, &audio.codec_context->ch_layout);
    tmp_audio_frame->sample_rate = audio.codec_context->sample_rate;
    tmp_audio_frame->nb_samples = audio.codec_context->frame_size;
    if (audio.codec_context->frame_size) {
        if (av_frame_get_buffer(tmp_audio_frame, 0) < 0) {
            fprintf(stderr, "Error allocating an audio buffer\n");
            return 1;
        }
    } else {
        fprintf(stderr, "No samples in audio frame\n");
        return 1;
    }

    // copy stream parameters to the muxer
    ret = avcodec_parameters_from_context(audio.stream->codecpar, audio.codec_context);
    if (ret < 0) {
        fprintf(stderr, "Could not copy the audio stream parameters\n");
        return 1;
    }

    // resampling context (not used for resampling but sample format conversion)
    swr_context = swr_alloc();
    if (!swr_context) {
        fprintf(stderr, "Could not allocate resampler context\n");
        return 1;
    }
    // in opts
    av_opt_set_chlayout(swr_context, "in_chlayout", &audio.codec_context->ch_layout, 0);
    av_opt_set_int(swr_context, "in_sample_rate", audio.codec_context->sample_rate, 0);
    av_opt_set_sample_fmt(swr_context, "in_sample_fmt", AV_SAMPLE_FMT_S16, 0);
    // out opts
    av_opt_set_chlayout(swr_context, "out_chlayout", &audio.codec_context->ch_layout, 0);
    av_opt_set_int(swr_context, "out_sample_rate", audio.codec_context->sample_rate, 0);
    av_opt_set_sample_fmt(swr_context, "out_sample_fmt", audio.codec_context->sample_fmt, 0);
    ret = swr_init(swr_context);
    if (ret < 0) {
        fprintf(stderr, "Failed to initialize the resampling context");
        return 1;
    }

    // set inital sample count
    samples_count = 0;
    // -----------------------------------------------------

    // check if output file was specified
    if (output_format->flags & AVFMT_NOFILE) {
        printf("No output file was specified.\n");
        return 1;
    }

    // print some info about the file
    av_dump_format(format_context, 0, filename, 1);

    // open the output file
    ret = avio_open(&format_context->pb, filename, AVIO_FLAG_WRITE);
    if (ret < 0) {
        fprintf(stderr, "Could not open '%s': %s\n", filename, av_err2str(ret));
        return 1;
    }
    // write the stream header
    ret = avformat_write_header(format_context, NULL);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file: %s\n",
            av_err2str(ret));
        return 1;
    }
    return 0;
}

static int write_frame(OutputStream* output) {
    int ret = avcodec_send_frame(output->codec_context, output->frame);
    if (ret < 0) {
        fprintf(stderr, "Error sending frame to the encoder: %s\n", av_err2str(ret));
        return 1;
    }
    while (ret >= 0) {
        ret = avcodec_receive_packet(output->codec_context, output->packet);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            break;
        } else if (ret < 0) {
            fprintf(stderr, "Error encoding a frame: %s\n", av_err2str(ret));
            return 1;
        }
        // rescale output packet timestamp values from codec to stream timebase
        av_packet_rescale_ts(output->packet, output->codec_context->time_base, output->stream->time_base);
        output->packet->stream_index = output->stream->index;

        // write the compressed frame to the media file
        ret = av_interleaved_write_frame(format_context, output->packet);
        // unreferencing of the packet not necessary as av_interleaved_write_frame takes ownership of it.
        if (ret < 0) {
            fprintf(stderr, "Error while writing output packet: %s\n", av_err2str(ret));
            return 1;
        }
    }
    return ret == AVERROR_EOF ? 1 : 0;
}

// returns the amount of samples in each frame (per channel)
int get_audio_frame_size() {
    return audio.codec_context->frame_size;
}

// returns 0 on success, 1 on failure
int supply_audio_data(const void* audio_data) {
    tmp_audio_frame->data[0] = (uint8_t*)audio_data;
    tmp_audio_frame->pts = audio.presentation_timestamp;
    audio.presentation_timestamp++;

    // calculate destination number of samples
    int dst_nb_samples = av_rescale_rnd(
        swr_get_delay(
            swr_context,
            audio.codec_context->sample_rate
        ) + tmp_audio_frame->nb_samples,
        audio.codec_context->sample_rate,
        audio.codec_context->sample_rate,
        AV_ROUND_UP
    );
    // the amount should not have changed
    av_assert0(dst_nb_samples == tmp_audio_frame->nb_samples);

    int ret = av_frame_make_writable(audio.frame);
    if (ret < 0) {
        fprintf(stderr, "Error making audio frame writable '%s'", av_err2str(ret));
        return 1;
    }

    // convert samples to destination format
    ret = swr_convert(
        swr_context,
        audio.frame->data,
        dst_nb_samples,
        (const uint8_t**)tmp_audio_frame->data,
        tmp_audio_frame->nb_samples
    );
    if (ret < 0) {
        fprintf(stderr, "Error while converting samples '%s'", av_err2str(ret));
        return 1;
    }
    audio.frame->pts = av_rescale_q(samples_count, (AVRational){1, audio.codec_context->sample_rate}, audio.codec_context->time_base);
    samples_count += dst_nb_samples;
    return write_frame(&audio);
}

// returns 0 on success, 1 on failure
int supply_video_data(const void* video_data) {
    // when passing a frame to the encoder, it may keep a reference to it. make sure to not overwrite it here
    int ret = av_frame_make_writable(video.frame);
    if (ret < 0) {
        fprintf(stderr, "Error making video frame writable '%s'", av_err2str(ret));
        return 1;
    }
    int line_size[] = {video.codec_context->width * 4};
    const uint8_t* color_data[] = {(const uint8_t*) video_data};
    sws_scale(sws_context, color_data, line_size, 0, video.codec_context->height, video.frame->data, video.frame->linesize);
    video.frame->pts = video.presentation_timestamp;
    video.presentation_timestamp++;
    return write_frame(&video);
}

static void close_stream(OutputStream* output_stream) {
    avcodec_free_context(&output_stream->codec_context);
    // already done for audio stream
    if (output_stream->frame) {
        av_frame_free(&output_stream->frame);
    }
    av_packet_free(&output_stream->packet);
}

void stop_encoding() {
    av_write_trailer(format_context);

    // flush
    av_frame_free(&audio.frame);
    audio.frame = NULL;
    write_frame(&audio);

    // close
    close_stream(&audio);
    close_stream(&video);

    // Close output file
    avio_closep(&format_context->pb);

    // free the stream
    avformat_free_context(format_context);
}
