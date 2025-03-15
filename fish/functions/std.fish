function std --wraps='systemctl poweroff' --description 'alias std=systemctl poweroff'
  systemctl poweroff $argv; 
end
