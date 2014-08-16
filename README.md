###About the GPD System

The GPD system is meant for people who spend a great deal of time text editing. It is a Todo app with the power of GTD and Mark Forster's Final Version with ninjitsu shortcuts for maximum workflow speed. Except for Section headers every line is a todo item. Special symbols allow you to understand different aspects of the todo item. Using combinations of regular and symbolic text, everything is free form text.  

###Pre-Requisites

To install GPD, you first need to install the Atom text editor. Go to the following link to download, http://atom.io/.

###Install Method
Will Bond has made a great plugin that loads packages into Sublime Text. If you use this method you will automatically get updates of GPD when they are released. I highly recommend using this approach.

1. Start Atom
2. Press `ctrl+shift+p` (Windows/Linux) or `command+shift+p` (Mac) and type Install Package. You should see "Settings View: Install Package".
3. In the search box, type "GPD" and press enter.
4. Find the GPD package and click the install button.

###Getting started
A few steps and you will be on your way.

1. Create new file and give it the extension `.GPD` and open it in Atom.
2. Type `///,Tab`. It will instantly give you the section layouts and put your cursor in the `Todo` section.
3. Create some Todos. Use symbols to note various aspects of the Todo. For all the symbols available (#, !, @, $, ~, \`) you can type `symbol,Tab` to enter them. All of the symbols represent different attributes of the todo:
	* `#,Tab` --> #(Project) - The project or group of work that this todo is part of.
	* `!,Tab` --> !(Target) - A measurable target for the todo. For example, a date, a specific performance metric, etc.
	* `@,Tab` --> @(Context) - People, places, or things that are related or required for the Todo. Such as a meeting room, a person whom you are waiting for or may need to call.
	* `$,Tab` --> $(Cost) - The amount of time or other cost metric that should be accounted for this todo.
	* `~,Tab` --> ~(Completion Date) - The date that you finished the todo.
	* ```,Tab`` --> `(Note ID) - An ID that references the Note attached to this todo
4. Once you got this under control, you will want to get familiar with the shortucts.

###Shortcuts
Shortcuts make GPD what it is, if you don't learn them it's not really going to work that well.

For Mac replace `ctrl` with `command`.

* `ctrl+shift+n` - Create a new Todo at the bottom of the //Todo// section
* `ctrl+shift+.` - Move the currently selected Todo at the top of the //Today// section
* `ctrl+shift+down` - Move the current todo at the top of //Closed// section and put a ~(datetime.now) at the front of the todo
* `ctrl+shift+up` - Do the same as `ctrl+shift+down` except it will also copy the todo to the bottom of the //Todo// section
* `ctrl+k,ctrl+,` - Get the note for this todo. It will either find or create the note for you in a companion `.GPD_Note` file. When in the GPD_Note file, you can press this again to switch back.

###Sections

Todos are divided into different sections. Today, Goals, and Closed. These sections are noted by `//Section Name//` followed by an `//End//`. The Today, Todo, and Closed sections are mandatory for this Sublime Text package. You can create any other sections you want.


###License
Copyright (c) 2014 Giampiero De Ciantis <gdeciantis@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
