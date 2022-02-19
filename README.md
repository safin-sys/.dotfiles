Packages
* Kitty
* Neofetch
* Fish

```
sudo pacman -S kitty neofetch fish fortune-mod
```

Extentions
* [Clear Top Bar](https://extensions.gnome.org/extension/4173/clear-top-bar/)
* [GSConnect](https://extensions.gnome.org/extension/1319/gsconnect/)
* [Just Perfection](https://extensions.gnome.org/extension/3843/just-perfection/)

Fonts Required
* Roboto
* Roboto Mono
* Nirmala UI

```
sudo pacman -S ttf-roboto ttf-roboto-mono
sudo mkdir -p /usr/local/share/fonts/ttf/NirmalaUI
sudo cp Nirmala.ttf /usr/local/share/fonts/ttf/NirmalaUI/
fc-cache
```
Appearance  

[Tokyo Nights Theme](https://github.com/stronk-dev/Tokyo-Night-Linux)  
[Flatery Icon](https://github.com/cbrnix/Flatery)  
```
https://github.com/cbrnix/Flatery.git
cd Flatery
./install.sh -v "Blue-Dark"
```

[Volantes Cursor](https://github.com/varlesh/volantes-cursors)
```
sudo pacman -S inkscape
git clone https://github.com/varlesh/volantes-cursors.git
cd volantes-cursors
make build
sudo make install
sudo pacman -Rns inkscape
```