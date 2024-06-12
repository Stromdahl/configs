# Configs
My personal dev-ops repo for managing my servers and workstations

## How to use

### Localy
``` bash
ansible-playbook -i inventory setup.yml -l <hostname> --ask-become-pass
```

## TODO

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
