{ ... }:

{
  # gruvbox https://github.com/morhetz/gruvbox-contrib/tree/master/xresources
  xresources.extraConfig = ''
    ! normal
    st.normbgcolor:      #000000
    st.normbordercolor:  #3c3836
    st.normfgcolor:      #ebdbb2

    ! selected
    st.selfgcolor:       #fbf1c7
    st.selbordercolor:   #d65d0e
    st.selbgcolor:       #000000

    dwm.normbordercolor: #3c3836
    dwm.normbgcolor: #282828
    dwm.normfgcolor: #ebdbb2
    dwm.selbordercolor: #d65d0e
    dwm.selbgcolor: #d65d0e
    dwm.selfgcolor: #fbf1c7

    Xcursor.theme: Vanilla-DMZ
    Xcursor.size: 32
  '';
}
