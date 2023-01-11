# dotfiles
https://www.webpro.nl/articles/getting-started-with-dotfiles
https://dotfiles.github.io/tutorials/

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
ansilbe-pull \
    -U https://github.com/Stromdahl/configs.yml \
    --aks-become-pass
```

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Stromdahl/configs/main/bootstrap)"
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
