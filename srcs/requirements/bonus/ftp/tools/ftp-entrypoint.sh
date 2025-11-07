#!/bin/sh
if [ ! -f "/etc/vsftpd/vsftpd.conf.bak" ]; then

        mkdir -p /var/www/html
        cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
        mv /tmp/vsftpd.conf /etc/vsftpd/vsftpd.conf

        # Use the host's external IP address for passive mode
        # This is the IP that external FTP clients will connect to
        EXTERNAL_IP="10.0.2.15"
        
        # Set the passive address configuration
        if grep -q "pasv_address=" /etc/vsftpd/vsftpd.conf; then
            sed -i "s/pasv_address=.*/pasv_address=$EXTERNAL_IP/" /etc/vsftpd/vsftpd.conf
        else
            echo "pasv_address=$EXTERNAL_IP" >> /etc/vsftpd/vsftpd.conf
        fi
        
        # Ensure other passive mode settings are present
        if ! grep -q "pasv_addr_resolve=" /etc/vsftpd/vsftpd.conf; then
            echo "pasv_addr_resolve=NO" >> /etc/vsftpd/vsftpd.conf
        fi
        if ! grep -q "pasv_promiscuous=" /etc/vsftpd/vsftpd.conf; then
            echo "pasv_promiscuous=YES" >> /etc/vsftpd/vsftpd.conf
        fi
        
        echo "FTP configured with external IP: $EXTERNAL_IP"

        # ADD ftp user, change the password and give the ownershipf of wordpress folder recursively
        adduser $FTP_USER --disabled-password
        echo "$FTP_USER:$FTP_PASSWORD" | chpasswd &> null
        chown -R $FTP_USER /var/www/html
        echo $FTP_USER | tee -a /etc/vsftpd.userlist &> /dev/null
fi
echo "FTP started on :21"
/usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf