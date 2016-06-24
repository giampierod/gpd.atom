### About the GPD System

The GPD system is meant for people who spend a great deal of time text editing. It is a Todo app with the power of GTD and Mark Forster's Final Version with ninjutsu shortcuts for maximum speed. Except for section headers, every line is a Todo item. Special symbols allow you to understand different aspects of the Todo item. Using combinations of regular and symbolic text, everything is free-form text.

### Pre-Requisites

To install GPD, you first need to install the Atom text editor. Go to the following link to download, http://atom.io/.

### Install Method
1. Start Atom
2. Press <kbd>ctrl</kbd><kbd>shift</kbd><kbd>p</kbd> (<kbd>⌘</kbd><kbd>⌥</kbd><kbd>p</kbd>) and type "Install Package". You should see "Settings View: Install Package".
3. In the search box, type "GPD" and press enter.
4. Find the GPD package and click the install button.

### Getting started
A few steps and you will be on your way.

1. Create new file, give it the extension `.GPD`, and open it in Atom.
2. Type `///,Tab`. It will instantly give you the section layouts and put your cursor in the `Backlog` section.
3. Create some Todos. Use symbols to note various aspects of the Todo. For all the symbols available (`#`, `!`, `@`, `$`, `~`, ` ` `) you can type <kbd>symbol</kbd> <kbd>tab</kbd> to enter them. All of the symbols represent different attributes of the Todo:
	* <kbd>#</kbd> <kbd>tab</kbd> → `#(Project)` - The project or group of work that this Todo is part of.
	* <kbd>!</kbd> <kbd>tab</kbd> → `!(Target)` - A measurable target for the Todo. E.g.: a date, a specific performance metric, etc.
	* <kbd>@</kbd> <kbd>tab</kbd> → `@(Context)` - People, places, or things that are related or required for the Todo. E.g.: a meeting room, a person who you are waiting for.
	* <kbd>$</kbd> <kbd>tab</kbd> → `$(Cost)` - The amount of time or other cost metric that should be accounted for this Todo.
	* <kbd>~</kbd> <kbd>tab</kbd> → `~(Completion Date)` - The date that you finished the Todo.
	* <kbd>,</kbd> <kbd>tab</kbd> → `(Note ID)` - An ID that references the Note attached to this Todo
4. Once you've mastered this, you will want to get familiar with the shortcuts.

### Shortcuts
Shortcuts make GPD what it is. If you don't learn them it's not really going to work that well.

* <kbd>ctrl</kbd><kbd>?</kbd> - Create a new Todo at the bottom of the ``//Backlog//`` section. If you are in a gpd_note file, the line you are currently on will be copied as a new note in the gpd file.
* <kbd>ctrl</kbd><kbd>.</kbd> - Move the currently selected Todo to the top of the ``//Todo//`` section
* <kbd>ctrl</kbd><kbd>}</kbd> - Move the current Todo to the top of ``//Closed//`` section and put a `~(datetime.now)` in front of it
* <kbd>ctrl</kbd><kbd>{</kbd> - As above, but also copy the Todo to the bottom of the ``//Backlog//`` section (for repeat tasks)
* <kbd>ctrl</kbd><kbd>,</kbd> - Find or create the note for current Todo in a companion `.GPD_Note` file. When in the `.GPD_Note` file, you can press this again to switch back the main `.GPD` file.
* <kbd>ctrl</kbd><kbd>[</kbd> - Narrow the view to a section folding the rest.
* <kbd>ctrl</kbd><kbd>]</kbd> - Unnarrow. I.e. Unfold-All
* <kbd>ctrl</kbd><kbd>$</kbd> - (experimental) Start or abort a 25 minute Pomodoro timer. Also appends an `O` to the cost metric field to mark the start of a Pomodoro. If you abort the Pomodoro, the `O` is replaced with a `/`, and if you finish the Pomodoro it is replaced with an `X`.


### Sections

Todos are divided into different sections: **Todo**, **Backlog**, and **Closed**. These sections are denoted by `//Section Name//` followed by `//End//`. The **Todo**, **Backlog**, and **Closed** sections are mandatory for this package, but you are free to create any other sections you want.

---------------

#### License
This project is licensed under the Apache License 2.0. The full license text can be found in the `LICENSE` file provided with this package.

Thank you to Yoshiori SHOJI who wrote the [original Pomodoro code][0], the license of which can be found in the `LICENSE_SHOJI` file provided with this package.

  [0]: https://github.com/yoshiori/pomodoro
