# Archivo de Reglas de Auditoría CIS - Consolidado y Ordenado

# 6.2.3.1 - 6.2.3.5 Configuración y Control de Acceso
-w /etc/audit/ -p wa -k audit_config_changes
-w /etc/libaudit.conf -p wa -k audit_config_changes
-w /etc/audisp/ -p wa -k audit_config_changes
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy

# 6.2.3.6 Ensure use of privileged commands are collected
-a always,exit -F path=/usr/sbin/unix_chkpwd -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/lib/x86_64-linux-gnu/utempter/utempter -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/lib/openssh/ssh-keysign -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/ssh-agent -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/dotlockfile -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/su -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/mount -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/gpasswd -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/newgrp -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/passwd -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/umount -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/crontab -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/expiry -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/chage -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/chsh -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F path=/usr/bin/chfn -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands

# 6.2.3.7 Ensure unsuccessful file access attempts are collected
-a always,exit -F arch=b64 -S creat,open,truncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access_denied
-a always,exit -F arch=b64 -S creat,open,truncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access_denied
-a always,exit -F arch=b32 -S creat,open,truncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access_denied
-a always,exit -F arch=b32 -S creat,open,truncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access_denied

# 6.2.3.8 Monitorización de cambios de UID/GID
-a always,exit -F arch=b64 -S setresuid,setresgid,setuid,setgid,setfsuid,setfsgid -F auid>=1000 -F auid!=4294967295 -k privileged_id_change
-a always,exit -F arch=b32 -S setresuid,setresgid,setuid,setgid,setfsuid,setfsgid -F auid>=1000 -F auid!=4294967295 -k privileged_id_change
-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=1000 -F auid!=4294967295 -k usermod
-a always,exit -F path=/usr/sbin/groupmod -F perm=x -F auid>=1000 -F auid!=4294967295 -k groupmod
-a always,exit -F path=/usr/sbin/chpasswd -F perm=x -F auid>=1000 -F auid!=4294967295 -k chpasswd

# 6.2.3.9 Identity and Authentication
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-w /etc/nsswitch.conf -p wa -k identity
-w /etc/pam.conf -p wa -k identity
-w /etc/pam.d -p wa -k identity

# 6.2.3.9 Discretionary access control permission modification events
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F path=/usr/bin/chcon -F perm=x -F auid>=1000 -F auid!=4294967295 -k perm_chcon
-a always,exit -F path=/usr/bin/chacl -F perm=x -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F path=/usr/bin/setfacl -F perm=x -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F path=/usr/bin/chmod -F perm=x -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F path=/usr/bin/chown -F perm=x -F auid>=1000 -F auid!=4294967295 -k perm_mod

# 6.2.3.10 Ensure successful file system mounts are collected
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F path=/usr/bin/mount -F perm=x -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F path=/usr/bin/umount -F perm=x -F auid>=1000 -F auid!=4294967295 -k mounts

# 6.2.3.11 Ensure session initiation information is collected
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins
-w /var/run/faillock -p wa -k logins
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
-a always,exit -F arch=b64 -S execve,fork,vfork,clone -F auid>=1000 -F auid!=4294967295 -k session
-a always,exit -F arch=b32 -S execve,fork,vfork,clone -F auid>=1000 -F auid!=4294967295 -k session

# 6.2.3.12 Monitorización de cambios en hora del sistema
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -F auid>=1000 -F auid!=4294967295 -k time_change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,stime,clock_settime -F auid>=1000 -F auid!=4294967295 -k time_change
-w /etc/localtime -p wa -k time_change

# 6.2.3.13 Ensure file deletion events by users are collected
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=4294967295 -k delete_events
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=4294967295 -k delete_events

# 6.2.3.15 Monitorear acceso a archivos de configuración de red
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/networks -p wa -k system-locale
-w /etc/network/ -p wa -k system-locale
-w /etc/netplan/ -p wa -k system-locale
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale

# 6.2.3.16 Ensure use of privileged commands is collected (Aunque el CIS la pone en 6.2.3.16, Nessus la busca en 6.2.3.2)
# Reglas para auditar el uso de privilegios para ejecutar comandos (euid != uid)
-a always,exit -F arch=b64 -C euid!=uid -F auid!=4294967295 -S execve -k user_emulation
-a always,exit -F arch=b32 -C euid!=uid -F auid!=4294967295 -S execve -k user_emulation

# 6.2.3.18 Ensure successful user and group modifications are collected
-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged_commands

# 6.2.3.19 Ensure kernel module loading, unloading, and modification is collected
-a always,exit -F arch=b64 -S init_module,finit_module,delete_module,create_module,query_module -F auid>=1000 -F auid!=4294967295 -k kernel_modules
-a always,exit -F arch=b32 -S init_module,finit_module,delete_module,create_module,query_module -F auid>=1000 -F auid!=4294967295 -k kernel_modules
-a always,exit -F path=/usr/bin/kmod -F perm=x -F auid>=1000 -F auid!=4294967295 -k kernel_modules
-a always,exit -F path=/usr/sbin/insmod -F perm=x -F auid>=1000 -F auid!=4294967295 -k kernel_modules
-a always,exit -F path=/usr/sbin/rmmod -F perm=x -F auid>=1000 -F auid!=4294967295 -k kernel_modules
-a always,exit -F path=/usr/sbin/modprobe -F perm=x -F auid>=1000 -F auid!=4294967295 -k kernel_modules

# Otros
-w /var/log/sudo.log -p wa -k sudo_log_file

# Inmutable
-e 2