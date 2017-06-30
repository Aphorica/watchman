# watchman
### Rick Berger, Aphorica Inc (rickb@aphorica.com)
---
The Sass folks (http://sass-lang.com) have re-written the sass processor in
Dart, which is an awesome thing.

However, what isn't implemented (as of yet) is the 'watch' capability.

Here is a little facility to provide that capability for Sass and a couple of nice
other features:
- processes a 'pubspec.src' file for environment substitution, if it exists.
  See the 'Pubspec' section below.
- copies listed files on change (which I needed.)

It is driven by a yaml config file:

    root: ( optional - uses the cwd, if not specified)
    sass:
      - lib
      - web/styles.css
    copy:
      - src-path: README.md
        dst-path: web/assets/about.md

#### Notes:
- As noted, the root is optional.
- In the 'sass' section: 
  - if the entry is a directory, the provided path will be
    scanned for files ending in '.sass' or '.scss'.  Those files will be added to
    the watch list.

  - If the entry is a single file, it will be added to the watch list (assuming it
    ends in '.sass' or '.scss').  This is one way to avoid other files you don't
    want watched or subdirectories you don't want scanned.

- On startup, the destination files are checked for existence.  If they are not, the
  correct procedure is invoked to create them.

- You can specify as many entries as you want.

#### Pubspec (experimental):
An issue with the 'pubspec.yaml' file is that it can't contain environment variables
(see this issue: https://github.com/dart-lang/pub/issues/1358).  That's a problem
when you bounce from environment to environment.

To address this, you can create a 'pubspec.src' file in the root directory that
contains environment variables interspersed in its content.  _watchman_ will
pick up that file and replace any environment specs in it with its
value and then write it out to the 'pubspec.yaml'.  If watching, the
'pubspec.src' file will be watched along with the other files, and write out the
corresponding 'pubspec.yaml' file on changes.

You can specify the environment variable in either Windows or *nix form - the
program will parse them out either way and do the substitutions.

After substituting, it will be written out to the 'pubspec.yaml' file.

## Installing as executable
Until I get it into the pub registry, do a git clone and:

    pub global activate --source path _(path to cloned dir)_ --overwrite

## Running
- Create a configuration file.  If 'root' is not specified, it will use the 'cwd' as
  the root path.  (If this is not correct, relative file specs will error.)

- Create a 'pubspec.src' if you want a pubspec with environment variables.

- Run _watchman_, pointing to the config file:

      watchman <-v -f -n> configfile.yaml <&>

Args:
<dl>
<dt>-v (verbose)</dt>
<dd>
If you specify '-v', it will output information on what it thinks it is doing.  Probably
not a bad thing to do the first couple of times you run it.</dd>
<dt>-f (force)</dt>
<dd>
Normally on init, the app only replaces/writes output files that don't exist.  
It doesn't know if the target app is out of date or not.  Specifying this flag will
cause it to output all files it knows about.</dd>
<dt>
<dt>-n (no watch)</dt>
<dd>
Processes as init and exits, without setting watches.  Useful for straight builds
without editing.</dd>
</dl>

#### Other
- (The ampersand ('&') is for *nix/osx users to put it in background mode.)

- You can run the flag args together, i.e. _-fn_.

## Caveats
This is _very_ lightly tested.  I plan to revisit with a more comprehensive test suite,
but it's working well enough for my purposes to use.  I'm putting it up on github so I
can pull it down to my various build environments.

I'm using it on OSX.  I wrote it to be FS agnostic, so it should work on Windows - certainly *nix -- but haven't tested it on those platforms, yet.

If you have need for something, ping me.  I can probably add something reasonable quickly.

## Future
I'm thinking about adding a general 'cmd' section that would allow any arbitrary process
that takes an input file and spits out an output file to be invoked.  Could be useful
for things like minification, filters, whatever.

The section would look something like:

    ...
    cmd:
      - cmdstr: "minify -q -i %src-path% -o %dst-path%"
        src-path: "js/tools.js"
        dst-path: "jslibs/tools.js.min"
    ...

Or something like that.