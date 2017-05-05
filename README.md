Overview
--------

DocTabs: a vim plugin for organizing a file into sections

Author: Janos Barbero <jbarbero@cs.washington.edu>

DocTabs is like having screen/tmux for a single buffer. Vim already
lets you manage different buffers very efficiently, but within a
buffer you are limited to jumping by searches or tags. With DocTabs,
however, you can organize a large file into sections, which you can
visualize and jump between. Each section keeps its own editing view
so you can jump back to where you were easily. The prefix-style
switching should be familiar to screen/tmux users. The tabline is
used to show all the sections and highlight the currently active
one, hence the plugin's name.

This is useful for a wide range of scenarios: documentation, source
code, HTML, project plans, todo or GTD files, reminder files,
journals, novels, your ~/.vimrc, etc. The DocTabs plugin and
documentation were both written using DocTabs.

For more information, check out doc/doctabs.txt

DocTabs is released under the GNU General Public License, version 3.

Asciicast
---------

[![asciicast](https://asciinema.org/a/107382.png)](https://asciinema.org/a/107382)

Versions
--------
- 0.9  Allow spaces in section names, pick up section changes sooner
- 0.8  Allow user-specified switching prefix
- 0.7  Allow alphanumeric tab labels for easier switching
- 0.6  Handle tabline overflow rendering
- 0.5  Highlight section headings, only update views when using jumps
- 0.4  Optional folding of other sections
- 0.3  Navigation functions to switch between sections
- 0.2  Save context for each section
- 0.1  Render tabline

