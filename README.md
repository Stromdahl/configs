# Configs
My personal dev-ops repo for managing my servers and workstations

## How to use

### Localy
``` bash
ansible-playbook \
--connection=local \ 
--inventory host, \
--limit host local.yml -i ansible/hosts --ask-become-pass
```

### Bootstrap
```
ansible-pull \
    -U https://github.com/Stromdahl/configs.yml \
    --ask-become-pass
```

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Stromdahl/configs/main/bootstrap)"
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
