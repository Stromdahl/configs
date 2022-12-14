# dotfiles
https://www.webpro.nl/articles/getting-started-with-dotfiles
https://dotfiles.github.io/tutorials/

# TODO

#### add this
```
$ cat /etc/X11/xorg.conf.d/90-custom-xkb.conf 
Section "InputClass"
	Identifier "Keyboard"
	MatchIsKeyboard "on"

	Option "XKbOptions" "caps:escape,lv3:rwin_switch"
EndSection
```
`https://johanegustafsson.net/projects/swerty/`
