# Contribution Guidelines
Thanks for considering to contribute to Open Hexagon CE.


## General
To not waste any work on something that doesn't fit in the scope of the game, talk to us either on discord or in a feature request github issue first.
The task will then be added to the prototype column of the [board](https://github.com/orgs/Open-Hexagon/projects/4/views/1).
If the suggestion gets accepted it will be added to the backlog, then you may assign yourself or get assigned to the task.

Code contributions must be tied to a task on the board.


## Code Style
We use [stylua](https://github.com/JohnnyMorganz/StyLua) to enforce our code style. Your editor likely has an extension for it as well.
Stylua does not enforce the amount of blank lines between blocks of code. However you should put at least one blank line between function definitions.
You may also put them elsewhere in the code where you see fit, but it is not required.

While it is not required at every point, functions and classes that are used many times in the code should be annotated with [LuaLS](https://luals.github.io/) style annotations. See [this page](https://luals.github.io/wiki/annotations/) for a list of supported annotations and examples. Many language servers use these for auto completion, so it is very useful. (Note that EmmyLua annotations are not compatible with LuaLS annotations.)

All requires should be made at the top of files and not inside functions or other statements. This makes it easy to immediately know what modules a file requires. It also discourages the use of cyclic dependencies which should be avoided. (This isn't a strict rule as sometimes there are good reasons to break this.)

**A word about gotos:** LuaJIT gives us labeled goto statements. We allow the use of gotos as they are very useful in certain situations and can make code more readable. Gotos must have descriptive labels. Examples of okay uses for goto are:

- Reducing indentation: Either by replicating continue statements, or creating guard clauses in places where a normal return wouldn't work.
- Handling errors or rare special cases.

## Design
The codebase is large and will only continue to grow. For this reason it is important to keep the following in mind:
- **Modularity**. The game is split into multiple modules that ideally are responsible for a single task/feature/object. It should be easy to get an overview of what a module does quickly, that means that not only naming should be clear but a single file should also never become very large.
- **No globals**. There should be no global variables besides the `love` variable. Globals are shared between modules and especially in a large codebase easily create hard to find issues.
- **Readability**. When looking at a single module, one should be able to tell what it does easily given a bit of time. This entails intuitive variable naming, comments and minimal code. Code being readable and easy to understand is more important than micro-optimizations!
- **Performance**. While micro-optimizations are to be avoided, structural decisions that have a great impact on performance should be made with it in mind.

## Target branch
All pull requests should target the main branch.
