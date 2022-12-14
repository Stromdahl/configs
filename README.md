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
```
// ┌─────┐
// │ 2 4 │   2 = Shift,  4 = Level3 + Shift
// │ 1 3 │   1 = Normal, 3 = Level3
// └─────┘
// ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┲━━━━━━━━━┓
// │ ~ ~ │ ! ' │ @ " │ # ˝ │ $ ¸ │ % ˇ │ ^ ^ │ & ˘ │ * ̇  │ ( ̣  │ ) ° │ _ ¯ │ + ˛ ┃ ⌫ Back- ┃
// │ ` ` │ 1 ¡ │ 2 © │ 3 • │ 4 § │ 5 € │ 6 ¢ │ 7 − │ 8 × │ 9 ÷ │ 0 ° │ - – │ = — ┃  space  ┃
// ┢━━━━━┷━┱───┴─┬───┴─┬───┴─┬───┴─┬───┴─┬───┴─┬───┴─┬───┴─┬───┴─┬───┴─┬───┴─┬───┺━┳━━━━━━━┫
// ┃       ┃ Q   │ W   │ E   │ R   │ T   │ Y   │ U   │ I   │ O   │ P   │ { « │ } » ┃ Enter ┃
// ┃Tab ↹  ┃ q   │ w   │ e   │ r   │ t   │ y   │ u   │ i   │ o   │ p   │ [ ‹ │ ] › ┃   ⏎   ┃
// ┣━━━━━━━┻┱────┴┬────┴┬────┴┬────┴┬────┴┬────┴┬────┴┬────┴┬────┴┬────┴┬────┴┬────┺┓      ┃
// ┃        ┃ A   │ S   │ D   │ F   │ G   │ H   │ J   │ K   │ L   │ : “ │ " ” │ | ¶ ┃      ┃
// ┃Caps ⇬  ┃ a   │ s   │ d   │ f   │ g   │ h   │ j   │ k   │ l   │ ; ‘ │ ' ’ │ \   ┃      ┃
// ┣━━━━━━━━┹────┬┴────┬┴────┬┴────┬┴────┬┴────┬┴────┬┴────┬┴────┬┴────┬┴────┲┷━━━━━┻━━━━━━┫
// ┃             │ Z   │ X   │ C   │ V   │ B   │ N   │ M   │ < „ │ > · │ ? ¿ ┃             ┃
// ┃Shift ⇧      │ z   │ x   │ c   │ v   │ b   │ n   │ m   │ , ‚ │ . … │ / ⁄ ┃Shift ⇧      ┃
// ┣━━━━━━━┳━━━━━┷━┳━━━┷━━━┱─┴─────┴─────┴─────┴─────┴─────┴───┲━┷━━━━━╈━━━━━┻━┳━━━━━━━┳━━━┛
// ┃       ┃       ┃       ┃ ␣                               ⍽ ┃       ┃       ┃       ┃
// ┃Ctrl   ┃Meta   ┃Alt    ┃ ␣           Space               ⍽ ┃AltGr ⇮┃Menu   ┃Ctrl   ┃
// ┗━━━━━━━┻━━━━━━━┻━━━━━━━┹───────────────────────────────────┺━━━━━━━┻━━━━━━━┻━━━━━━━┛
```
`https://johanegustafsson.net/projects/swerty/`
