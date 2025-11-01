--[[
Edited version of https://raw.githubusercontent.com/thenumbernine/http-lua/master/class.lua to remove most of the dependencies for a more minimal version
--]]
local socket = require("socket")
local url = require("socket.url")
local json = require("json.json")

local mimes = {
    ["3gp"] = "video/3gpp",
    a = "application/octet-stream",
    ai = "application/postscript",
    aif = "audio/x-aiff",
    aiff = "audio/x-aiff",
    asc = "application/pgp-signature",
    asf = "video/x-ms-asf",
    asm = "text/x-asm",
    asx = "video/x-ms-asf",
    atom = "application/atom+xml",
    au = "audio/basic",
    avi = "video/x-msvideo",
    bat = "application/x-msdownload",
    bin = "application/octet-stream",
    bmp = "image/bmp",
    bz2 = "application/x-bzip2",
    c = "text/x-c",
    cab = "application/vnd.ms-cab-compressed",
    cc = "text/x-c",
    chm = "application/vnd.ms-htmlhelp",
    class = "application/octet-stream",
    com = "application/x-msdownload",
    conf = "text/plain",
    cpp = "text/x-c",
    crt = "application/x-x509-ca-cert",
    css = "text/css",
    csv = "text/csv",
    cxx = "text/x-c",
    deb = "application/x-debian-package",
    der = "application/x-x509-ca-cert",
    diff = "text/x-diff",
    djv = "image/vnd.djvu",
    djvu = "image/vnd.djvu",
    dll = "application/x-msdownload",
    dmg = "application/octet-stream",
    doc = "application/msword",
    dot = "application/msword",
    dtd = "application/xml-dtd",
    dvi = "application/x-dvi",
    ear = "application/java-archive",
    eml = "message/rfc822",
    eps = "application/postscript",
    exe = "application/x-msdownload",
    f = "text/x-fortran",
    f77 = "text/x-fortran",
    f90 = "text/x-fortran",
    flv = "video/x-flv",
    ["for"] = "text/x-fortran",
    gem = "application/octet-stream",
    gemspec = "text/x-script.ruby",
    gif = "image/gif",
    gz = "application/x-gzip",
    h = "text/x-c",
    hh = "text/x-c",
    htm = "text/html",
    html = "text/html",
    ico = "image/vnd.microsoft.icon",
    ics = "text/calendar",
    ifb = "text/calendar",
    iso = "application/octet-stream",
    jar = "application/java-archive",
    java = "text/x-java-source",
    jnlp = "application/x-java-jnlp-file",
    jpeg = "image/jpeg",
    jpg = "image/jpeg",
    js = "application/javascript",
    json = "application/json",
    less = "text/css",
    log = "text/plain",
    lua = "text/x-lua",
    luac = "application/x-lua-bytecode",
    m3u = "audio/x-mpegurl",
    m4v = "video/mp4",
    man = "text/troff",
    manifest = "text/cache-manifest",
    markdown = "text/markdown",
    mathml = "application/mathml+xml",
    mbox = "application/mbox",
    mdoc = "text/troff",
    md = "text/markdown",
    me = "text/troff",
    mid = "audio/midi",
    midi = "audio/midi",
    mime = "message/rfc822",
    mml = "application/mathml+xml",
    mng = "video/x-mng",
    mov = "video/quicktime",
    mp3 = "audio/mpeg",
    mp4 = "video/mp4",
    mp4v = "video/mp4",
    mpeg = "video/mpeg",
    mpg = "video/mpeg",
    ms = "text/troff",
    msi = "application/x-msdownload",
    odp = "application/vnd.oasis.opendocument.presentation",
    ods = "application/vnd.oasis.opendocument.spreadsheet",
    odt = "application/vnd.oasis.opendocument.text",
    ogg = "application/ogg",
    p = "text/x-pascal",
    pas = "text/x-pascal",
    pbm = "image/x-portable-bitmap",
    pdf = "application/pdf",
    pem = "application/x-x509-ca-cert",
    pgm = "image/x-portable-graymap",
    pgp = "application/pgp-encrypted",
    pkg = "application/octet-stream",
    pl = "text/x-script.perl",
    pm = "text/x-script.perl-module",
    png = "image/png",
    pnm = "image/x-portable-anymap",
    ppm = "image/x-portable-pixmap",
    pps = "application/vnd.ms-powerpoint",
    ppt = "application/vnd.ms-powerpoint",
    ps = "application/postscript",
    psd = "image/vnd.adobe.photoshop",
    py = "text/x-script.python",
    qt = "video/quicktime",
    ra = "audio/x-pn-realaudio",
    rake = "text/x-script.ruby",
    ram = "audio/x-pn-realaudio",
    rar = "application/x-rar-compressed",
    rb = "text/x-script.ruby",
    rdf = "application/rdf+xml",
    roff = "text/troff",
    rpm = "application/x-redhat-package-manager",
    rss = "application/rss+xml",
    rtf = "application/rtf",
    ru = "text/x-script.ruby",
    s = "text/x-asm",
    sgm = "text/sgml",
    sgml = "text/sgml",
    sh = "application/x-sh",
    sig = "application/pgp-signature",
    snd = "audio/basic",
    so = "application/octet-stream",
    svg = "image/svg+xml",
    svgz = "image/svg+xml",
    swf = "application/x-shockwave-flash",
    t = "text/troff",
    tar = "application/x-tar",
    tbz = "application/x-bzip-compressed-tar",
    tci = "application/x-topcloud",
    tcl = "application/x-tcl",
    tex = "application/x-tex",
    texi = "application/x-texinfo",
    texinfo = "application/x-texinfo",
    text = "text/plain",
    tif = "image/tiff",
    tiff = "image/tiff",
    torrent = "application/x-bittorrent",
    tr = "text/troff",
    ttf = "application/x-font-ttf",
    txt = "text/plain",
    vcf = "text/x-vcard",
    vcs = "text/x-vcalendar",
    vrml = "model/vrml",
    war = "application/java-archive",
    wav = "audio/x-wav",
    webm = "video/webm",
    wma = "audio/x-ms-wma",
    wmv = "video/x-ms-wmv",
    wmx = "video/x-ms-wmx",
    wrl = "model/vrml",
    wsdl = "application/wsdl+xml",
    xbm = "image/x-xbitmap",
    xhtml = "application/xhtml+xml",
    xls = "application/vnd.ms-excel",
    xml = "application/xml",
    xpm = "image/x-xpixmap",
    xsl = "application/xml",
    xslt = "application/xslt+xml",
    yaml = "text/yaml",
    yml = "text/yaml",
    zip = "application/zip",
}
mimes.default = "application/octet-stream"

-- escape for pattern matching
local escapeFind = "[" .. ([[^$()%.[]*+-?]]):gsub(".", "%%%1") .. "]"
local function patescape(s)
    return (s:gsub(escapeFind, "%%%1"))
end

local HTTP = {}
HTTP.__index = HTTP

--[[
args:
	addr = address to bind to, default *
	port = port to use, default 8000.  port=false means don't use non-ssl connections
	sslport = ssl port to use, default 8001. sslport=false means don't use ssl connections.
	keyfile = ssl key file
	certfile = ssl cert file
	block = whether to use blocking, default true
		block = true will have problems if port and sslport are used, since you'll have two blocking server sockets
	config = where to store the mimetypes file
	log = log level.  level 0 = none, 1 = only most serious, 2 3 etc = more and more information, all the way to infinity.
--]]
function HTTP:new(args)
    local obj = setmetatable({}, HTTP)
    obj:init(args)
    return obj
end

function HTTP:init(args)
    args = args or {}

    self.loglevel = args.log or 0

    self.working = 0

    self.allow_cors = args.allow_cors
    self.allowed_folders = args.allowed_folders or {}
    self.handlers = {}

    self.servers = {}
    local boundaddr, boundport

    local addr = args.addr or "*"
    local port = args.port
    if port then
        self:log(3, "bind addr port " .. tostring(addr) .. ":" .. tostring(port))
        self.server = assert(socket.bind(addr, port))
        self.servers[#self.servers + 1] = self.server
        boundaddr, boundport = self.server:getsockname()
        self.port = boundport
        self:log(1, "listening " .. tostring(boundaddr) .. ":" .. tostring(boundport))
    end

    local sslport = args.sslport
    if sslport or args.keyfile or args.certfile then
        if sslport and args.keyfile and args.certfile then
            self.keyfile = args.keyfile
            self.certfile = args.certfile
            assert(io.open(self.keyfile), "failed to find keyfile " .. self.keyfile)
            assert(io.open(self.certfile), "failed to find certfile " .. self.certfile)
            self:log(3, "bind ssl addr port " .. tostring(addr) .. ":" .. tostring(sslport))
            self.sslserver = assert(socket.bind(addr, sslport))
            self.servers[#self.servers + 1] = self.sslserver
            boundaddr, boundport = self.sslserver:getsockname()
            self.sslport = boundport
            self:log(1, "ssl listening " .. tostring(boundaddr) .. ":" .. tostring(boundport))
            self:log(1, "key file " .. tostring(self.keyfile))
            self:log(1, "cert file " .. tostring(self.certfile))
        else
            print("WARNING: for ssl to work you need to specify sslport, keyfile, certfile")
        end
    end

    self:log(3, "# server sockets " .. tostring(#self.servers))

    self.block = args.block
    -- use blocking by default.
    -- I had some trouble with blocking and MathJax on android.  Maybe it was my imagination.
    if self.block == nil then
        self.block = false
    end
    self:log(1, "blocking? " .. tostring(self.block))

    if self.block then
        --[[ not necessary?
		for _,server in ipairs{self.server, self.sslserver} do
			assert(server:settimeout(3600))
			server:setoption('keepalive',true)
			server:setoption('linger',{on=true,timeout=3600})
		end
		--]]
        if #self.servers > 1 then
            self:log(
                0,
                "WARNING: you're using blocking with two listening ports.  You will experience unexpected lengthy delays."
            )
        end
    else
        -- [[
        for _, server in ipairs(self.servers) do
            assert(server:settimeout(0, "b"))
            assert(server:settimeout(0, "t"))
        end
        --]]
    end

    self.clients = {}
    self.couroutine_client_map = {}
end

function HTTP:send(conn, data)
    self:log(10, conn, "<<", data)
    local timeout_count = 0
    local i = 1
    while true do
        -- conn:send() successful response will be numberBytesSent, nil, nil, time
        -- conn:send() failed response will be nil, 'wantwrite', numBytesSent, time
        -- socket.send lets you use i,j as substring args, but does luasec's ssl.wrap?
        local successlen, reason, faillen, time = conn:send(data:sub(i))
        self:log(10, conn, "...", successlen, reason, faillen, time)
        self:log(10, conn, "...getstats()", conn:getstats())
        if successlen ~= nil then
            assert(reason ~= "wantwrite") -- will wantwrite get set only if res[1] is nil?
            self:log(10, conn, "...done sending")
            return successlen, reason, faillen, time
        end
        if reason == "timeout" then
            timeout_count = timeout_count + 1
            if timeout_count > 10000000 then
                return nil, reason, faillen, time
            end
        elseif reason ~= "wantwrite" then
            return nil, reason, faillen, time
        end
        --socket.select({conn}, nil)	-- not good?
        -- try again
        i = i + faillen
        self:log(10, conn, "sending from offset " .. i)
        coroutine.yield()
    end
end

function HTTP:log(level, ...)
    if level > self.loglevel then
        return
    end
    print(...)
end

function HTTP.file(path, headers, reqHeaders)
    local CHUNK_SIZE = 1024
    local ext = path:match(".*%.(.*)")
    headers["content-type"] = ext and mimes[ext:lower()] or mimes.default
    headers["accept-ranges"] = "bytes"
    local file = love.filesystem.openFile(path, "r")
    local file_size = file:getSize()
    local start_pos = 0
    local to_read = file_size
    if reqHeaders["range"] then
        local unit, range_start, range_end = reqHeaders["range"]:match("(.*)=(%d*)%-(%d*)")
        range_start = tonumber(range_start)
        range_end = tonumber(range_end)
        if not range_start then
            -- range_end is the suffix length in this case
            range_start = file_size - range_end
            range_end = file_size - 1
        elseif not range_end then
            -- no end given means end of the resource
            range_end = file_size - 1
        end
        if unit ~= "bytes" or range_start > range_end or range_start < 0 or range_end < 0 or range_end >= file_size then
            local message = "invalid range: '" .. reqHeaders["range"] .. "'"
            headers["content-type"] = "text/plain"
            headers["content-length"] = #message
            return coroutine.wrap(function()
                coroutine.yield(message)
            end), "400"
        end
        start_pos = range_start
        to_read = range_end + 1 - range_start
        headers["content-range"] = string.format("bytes %d-%d/%d", range_start, range_end, file_size)
    end
    file:seek(start_pos)
    headers["content-length"] = to_read
    headers["transfer-encoding"] = to_read > CHUNK_SIZE and "chunked" or nil
    return coroutine.wrap(function()
        if to_read <= CHUNK_SIZE then
            coroutine.yield(file:read(to_read))
        else
            while to_read > 0 do
                local chunk = file:read(CHUNK_SIZE)
                to_read = to_read - CHUNK_SIZE
                coroutine.yield(string.format("%x\r\n%s\r\n", #chunk, chunk))
            end
            coroutine.yield("0\r\n\r\n")
        end
        file:close()
    end),
        reqHeaders["range"] and "206" or "200" -- 206 is partial content
end

function HTTP:handleFile(filename, localfilename, ext, dir, headers, reqHeaders, GET, POST)
    local result = love.filesystem.read(localfilename)
    if not result then
        self:log(1, "failed to read file at", localfilename)
        return "403 Forbidden",
            coroutine.wrap(function()
                coroutine.yield("failed to read file " .. filename)
            end)
    end

    self:log(1, "serving file", filename)
    return "200 OK", HTTP.file(localfilename, headers, reqHeaders)
end

function HTTP:handleRequest(...)
    self:log(2, "HTTP:handleRequest", ...)
    local filename, headers, reqHeaders, method, proto, GET, POST = ...

    headers["cache-control"] = "no-cache, no-store, must-revalidate"
    headers["pragma"] = "no-cache"
    headers["expires"] = "0"

    local captures
    local handler_search_result
    for pattern, handler in pairs(self.handlers) do
        captures = {}
        local url_iter = filename:gmatch("([^/]*)/?")
        local matches = true
        for part in pattern:gmatch("([^/]*)/?") do
            if part == "..." then
                captures[#captures + 1] = url_iter()
            else
                if part ~= url_iter() then
                    matches = false
                    break
                end
            end
        end
        matches = matches and url_iter() == nil
        if matches then
            handler_search_result = handler
            break
        end
    end
    if handler_search_result then
        local coroutine_or_string, return_code = handler_search_result(captures, headers, reqHeaders, GET, POST)
        if type(coroutine_or_string) == "string" then
            local CHUNK_SIZE = 1024 -- only for strings (file chunk size is separate)
            local str = coroutine_or_string
            headers["content-type"] = headers["content-type"] or "text/plain"
            headers["content-length"] = #str
            if headers["content-length"] <= CHUNK_SIZE then
                coroutine_or_string = coroutine.wrap(function()
                    coroutine.yield(str)
                end)
            else
                headers["transfer-encoding"] = "chunked"
                local pos = 0
                coroutine_or_string = coroutine.wrap(function()
                    repeat
                        -- this is the only place with the number, so chunk size can be adjusted here
                        local chunk = str:sub(pos, pos + CHUNK_SIZE - 1)
                        pos = pos + CHUNK_SIZE
                        local len = #chunk
                        coroutine.yield(string.format("%x\r\n%s\r\n", len, chunk))
                    until len == 0
                end)
            end
        end
        return return_code or "200 OK", coroutine_or_string
    end

    local folder = filename:match(".*/")
    local allowed = false
    for i = 1, #self.allowed_folders do
        if self.allowed_folders[i] == folder then
            allowed = true
        end
    end

    if allowed then
        self:log(1, "searching in " .. folder)

        local localfilename = filename:gsub("/+", "/")
        local info = love.filesystem.getInfo(localfilename)
        if info and info.type == "file" then
            -- handle file:
            local ext = localfilename:match(".*%.(.*)")
            local dirforfile = localfilename:match(".*/")
            self:log(1, "ext", ext)
            self:log(1, "dirforfile", dirforfile)

            return self:handleFile(filename, localfilename, ext, dirforfile, headers, reqHeaders, GET, POST)
        else
            self:log(1, "from searchdir failed to find file at", localfilename)
        end
    end

    self:log(1, "failed to find any files at", filename)
    return "404 Not Found",
        coroutine.wrap(function()
            coroutine.yield("failed to find file " .. filename)
        end)
end

-- this is coroutine-blocking
-- kinda matches websocket
-- but it has read amount (defaults to *l)
-- soon these two will merge, and this whole project will have gotten out of hand
function HTTP:receive(conn, amount, waitduration)
    amount = amount or "*l"
    coroutine.yield()

    local endtime
    if waitduration then
        endtime = self.getTime() + waitduration
    end
    local data
    repeat
        local reason
        data, reason = conn:receive(amount)
        self:log(10, conn, "...", data, reason)
        self:log(10, conn, "...getstats()", conn:getstats())
        if reason == "wantread" then
            -- can we have data AND wantread?
            assert(not data, "FIXME I haven't considered wantread + already-read data")
            --self:log(10, 'got wantread, calling select...')
            socket.select(nil, { conn })
            --self:log(10, '...done calling select')
            -- and try again
        else
            if data then
                self:log(10, conn, ">>", data)
                return data
            end
            if reason ~= "timeout" then
                self:log(10, "connection failed:", reason)
                return nil, reason -- error() ?
            end
            -- else check timeout
            if waitduration and self.getTime() > endtime then
                return nil, "timeout"
            end
            -- continue
        end
        coroutine.yield()
    until data ~= nil
end

function HTTP:handleClient(client)
    local request = self:receive(client)
    if not request then
        return true
    end

    local increased_working = false
    xpcall(function()
        self:log(1, "got request", request)
        local parts = {}
        for part in request:gmatch("([^%s]*)%s?") do
            if part ~= "" then
                parts[#parts + 1] = part
            end
        end
        local method, filename, proto = unpack(parts)

        local POST
        local reqHeaders = {}
        while true do
            local line = self:receive(client)
            if not line then
                break
            end
            line = line:match("^%s*(.-)%s*$")
            if line == "" then
                self:log(1, "done reading header")
                break
            end
            local k, v = line:match("^(.-):(.*)$")
            if not k then
                self:log(1, "got invalid header line: " .. line)
                break
            end
            v = v:match("^%s*(.-)%s*$")
            reqHeaders[k:lower()] = v
            self:log(3, "reqHeaders[" .. k:lower() .. "] = " .. v)
        end

        method = method:lower()
        if method == "get" then
            -- fall through, don't error
            -- [[
        elseif method == "post" then
            local postLen = tonumber(reqHeaders["content-length"])
            if not postLen then
                self:log(0, "didn't get POST data length")
            else
                self:log(1, "reading POST " .. postLen .. " bytes")
                local postData = self:receive(client, postLen) or ""
                self:log(1, "read POST data: " .. postData)
                local contentType = reqHeaders["content-type"]:match("^%s*(.-)%s*$")
                local contentTypeParts = {}
                for s in contentType:gmatch("([^;]*);?") do
                    contentTypeParts[#contentTypeParts + 1] = s:match("^%s*(.-)%s*$")
                end
                local contentTypePartsMap = {} -- first one is the content-type, rest are key=value
                for _, part in ipairs(contentTypeParts) do
                    local k, v = part:match("([^=]*)=(.*)")
                    if not k then
                        self:log(0, "got unknown contentType part " .. part)
                    else
                        k = k:match("^%s*(.-)%s*$"):lower() -- case-insensitive right?
                        v = v:match("^%s*(.-)%s*$")
                        contentTypePartsMap[k] = v
                    end
                end
                if contentTypeParts[1] == "application/json" then
                    POST = json.decode(postData)
                elseif contentTypeParts[1] == "application/x-www-form-urlencoded" then
                    self:log(2, "splitting up post...")
                    POST = {}
                    for part in postData:gmatch("([^&]*)&?") do
                        local k, v = part:match("([^=]*)=(.*)")
                        if not v then
                            k, v = part, ""
                        end
                        self:log(10, "before unescape, k=" .. k .. " v=" .. v)

                        -- plusses are already encoded as %2B, right?
                        -- because it looks like jQuery ajax() POST is replacing ' ' with '+'
                        k = k:gsub("+", " ")
                        k = url.unescape(k)
                        if type(v) == "string" then
                            v = v:gsub("+", " ")
                            v = url.unescape(v)
                        end
                        self:log(10, "after unescape, k=" .. k .. " v=" .. v)
                        POST[k] = v
                    end
                elseif contentTypeParts[1] == "multipart/form-data" then
                    local boundary = contentTypePartsMap.boundary
                    local splitter = patescape("--" .. boundary)
                    local postparts = {}
                    for part in postData:gmatch("([^" .. splitter .. "]*)" .. splitter .. "?") do
                        postparts[#postparts + 1] = part
                    end
                    assert(postparts:remove(1) == "")
                    POST = {}
                    while #postparts > 0 do
                        local formInputData = postparts:remove(1)
                        self:log(2, "form-data part:\n" .. formInputData)
                        local lines = {}
                        for line in formInputData:gmatch("([^\r\n]*)\r\n?") do
                            lines[#lines + 1] = line
                        end
                        self:log(3, lines)
                        if #postparts == 0 then
                            assert(lines[1] == "--")
                            assert(lines[2] == "")
                            assert(#lines == 2)
                            break
                        end
                        assert(lines:remove(1) == "")
                        -- then do another header-read here with k:v; .. kinda with some optional stuff too ...
                        -- who thinks this stupid standard up? we have some k:v, some k=v, ...some bullshit
                        local thisPostVar = {}
                        while lines[1] ~= nil and lines[1] ~= "" do
                            -- in here is all the important stuff:
                            local nextline = lines:remove(1)
                            self:log(2, "next line:\n" .. nextline)
                            local splits = {}
                            for split in nextline:gmatch("([^;]*);?") do
                                splits[#splits + 1] = split
                            end
                            for i, split in ipairs(splits) do
                                split = split:match("^%s*(.-)%s*$")
                                -- order probably matters
                                local k, v
                                if i == 1 then
                                    k, v = split:match("([^:]*):(.*)$")
                                    if k == nil or v == nil then
                                        error("failed to parse POST form-data line " .. split)
                                    end
                                else
                                    k, v = split:match('([^=]*)="(.*)"$')
                                    if k == nil or v == nil then
                                        error("failed to parse POST form-data line " .. split)
                                    end
                                end
                                thisPostVar[k:lower()] = v:match("^%s*(.-)%s*$")
                            end
                        end
                        assert(lines[1] ~= nil, "removed too many lines in our form-part data")
                        assert(lines:remove(1) == "")
                        assert(lines:remove() == "")
                        local data = lines:concat("\r\n")
                        self:log(3, "setting post var " .. tostring(thisPostVar.name) .. " to data len " .. #data)
                        POST[thisPostVar.name] = thisPostVar
                        POST[thisPostVar.name].body = data
                    end
                else
                    self:log(1, "what to do with post and our content-type " .. tostring(contentType))
                    POST = postData
                end
            end
        --]]
        else
            error("unknown method: " .. method)
        end

        filename = url.unescape(filename:gsub("%+", "%%20"))
        local base, GET = filename:match("(.-)%?(.*)")

        self:log(3, "about to handleRequest with " .. json.encode({ GET = GET, POST = POST }))

        filename = base or filename
        if not filename then
            self:log(1, "couldn't find filename in request " .. ("%q"):format(request))
        else
            local headers = {}
            headers["Connection"] = "close"
            if self.allow_cors then
                headers["Access-Control-Allow-Origin"] = "*"
            end
            local status, callback = self:handleRequest(filename, headers, reqHeaders, method, proto, GET, POST)

            assert(self:send(client, "HTTP/1.1 " .. status .. "\r\n"))
            for k, v in pairs(headers) do
                assert(self:send(client, k .. ": " .. v .. "\r\n"))
            end
            assert(self:send(client, "\r\n"))
            if callback then
                self.working = self.working + 1
                increased_working = true
                for str in callback do
                    coroutine.yield()
                    -- closed connection during sending of longer data
                    -- usually just means the browser noticed it's too much
                    -- and aborted in order to start again with ranged requests
                    local successlen, reason = self:send(client, str)
                    assert(successlen or reason == "closed", reason)
                end
                self.working = self.working - 1
                increased_working = false
            else
                assert(self:send(client, [[someone forgot to set a callback!]]))
            end
        end
    end, function(err)
        if increased_working then
            self.working = self.working - 1
        end
        io.stderr:write(err .. "\n" .. debug.traceback() .. "\n")
    end)
end

function HTTP:connectCoroutine(client, server)
    self:log(1, "got connection!", client)
    assert(client)
    assert(server)
    self:log(2, "connection from", client:getpeername())
    self:log(2, "connection to", server:getsockname())
    self:log(2, "creating new coroutine...")

    -- TODO for block as well
    if server == self.sslserver then
        -- from https://stackoverflow.com/questions/2833947/stuck-with-luasec-lua-secure-socket
        -- TODO need to specify cert files
        -- TODO but if you want to handle both https and non-https on different ports, that means two connections, that means better make non-blocking the default
        --assert(client:settimeout(10))
        self:log(3, "ssl server calling ssl.wrap...")
        self:log(1, "key file " .. tostring(self.keyfile))
        self:log(1, "cert file " .. tostring(self.certfile))
        local ssl = require("ssl") -- package luasec
        client = assert(ssl.wrap(client, {
            mode = "server",
            options = { "all" },
            protocol = "any",
            key = assert(self.keyfile),
            certificate = assert(self.certfile),
            ciphers = "ALL:!ADH:@STRENGTH",
        }))

        if not self.block then
            assert(client:settimeout(0, "b"))
            assert(client:settimeout(0, "t"))
        end

        self:log(3, "waiting for handshake")
        local result, reason
        while not result do
            coroutine.yield()
            result, reason = client:dohandshake()
            if reason ~= "wantread" then
                self:log(3, "client:dohandshake", result, reason)
            end
            if reason == "wantread" then
                socket.select(nil, { client })
                -- and try again
            elseif not result then
                -- then error
                error("handshake failed: " .. tostring(reason))
            end
            if reason == "unknown state" then
                error("handshake conn in unknown state")
            end
            -- result == true and we can stop
        end
        self:log(3, "got handshake")
    end
    self:log(1, "got client!")
    self.clients[#self.clients + 1] = client
    self:log(1, "total #clients", #self.clients)

    if not self:handleClient(client) then
        self:log(1, "closing client...")
        self:receive(client, 1)
    end
    client:close()
    for i = 1, #self.clients do
        if self.clients[i] == client then
            table.remove(self.clients, i)
            break
        end
    end
    self:log(2, "# clients remaining: " .. #self.clients)
end

function HTTP:close_and_remove_client(co)
    local client = self.couroutine_client_map[co]
    self:log(0, "Forcibly closing client:", pcall(client.close, client))
    for i = 1, #self.clients do
        if self.clients[i] == client then
            table.remove(self.clients, i)
            break
        end
    end
end

function HTTP:run()
    while true do
        self:run_once()
    end
end

function HTTP:run_once()
    self.coroutines = self.coroutines or {}
    for _, server in ipairs(self.servers) do
        if self.block then
            -- blocking is easiest with single-server-socket impls
            -- tho it had problems on android luasocket iirc
            -- and now that i'm switching to ssl as well, ... gonna have problems
            self:log(1, "waiting for client...")
            local client = assert(server:accept())
            assert(client:settimeout(3600, "b"))
            local new_coroutine = coroutine.create(self.connectCoroutine)
            self.couroutine_client_map[new_coroutine] = client
            local index = #self.coroutines + 1
            self.coroutines[index] = new_coroutine
            local success, err = coroutine.resume(new_coroutine, self, client, server)
            if not success then
                self:log(0, "Error in coroutine:", err .. "\n" .. debug.traceback(new_coroutine))
                self:close_and_remove_client(new_coroutine)
            end
        else
            local client = server:accept()
            if client then
                -- [[ should the client be non-blocking as well?  or can we assert the client will respond in time?
                assert(client:setoption("keepalive", true))
                assert(client:settimeout(0, "b"))
                assert(client:settimeout(0, "t"))
                --]]
                local new_coroutine = coroutine.create(self.connectCoroutine)
                self.couroutine_client_map[new_coroutine] = client
                local index = #self.coroutines + 1
                self.coroutines[index] = new_coroutine
                local success, err = coroutine.resume(new_coroutine, self, client, server)
                if not success then
                    self:log(0, "Error in coroutine:", err .. "\n" .. debug.traceback(new_coroutine))
                    self:close_and_remove_client(new_coroutine)
                end
            end
        end
    end
    for i = #self.coroutines, 1, -1 do
        if coroutine.status(self.coroutines[i]) == "dead" then
            self.couroutine_client_map[self.coroutines[i]] = nil
            table.remove(self.coroutines, i)
        else
            local success, err = coroutine.resume(self.coroutines[i])
            if not success then
                self:log(0, "Error in coroutine:", err .. "\n" .. debug.traceback(self.coroutines[i]))
                self:close_and_remove_client(self.coroutines[i])
            end
        end
    end
    if #self.clients == 0 then
        love.timer.sleep(0.1)
    elseif self.working == 0 then
        love.timer.sleep(0.01)
    end
    return #self.clients == 0 or self.working == 0
end

return HTTP
