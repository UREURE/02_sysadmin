#!/bin/bash

# Actualizar repositorio de paquetes
sudo apt-get update

# Instalar LVM2
sudo apt-get install lvm2 -y

# Particionar los discos
sudo sfdisk /dev/sdb < /vagrant/wiki/lvm_part_table
sudo sfdisk /dev/sdc < /vagrant/wiki/lvm_part_table
sudo sfdisk /dev/sdd < /vagrant/wiki/lvm_part_table
sudo sfdisk /dev/sde < /vagrant/wiki/lvm_part_table

# Crear los volúmenes físicos
sudo /sbin/pvcreate /dev/sdb1
sudo /sbin/pvcreate /dev/sdc1
sudo /sbin/pvcreate /dev/sdd1
sudo /sbin/pvcreate /dev/sde1

# Crear el volume group
sudo /sbin/vgcreate debwiki_vg /dev/sdb1
# Extender el volume group
sudo /sbin/vgextend debwiki_vg /dev/sdc1
sudo /sbin/vgextend debwiki_vg /dev/sdd1
sudo /sbin/vgextend debwiki_vg /dev/sde1
# Crear el volumen lógico en RAID 5
sudo /sbin/lvcreate --type raid5 -l 100%FREE debwiki_vg -n debwiki_data
# Dar formato al volumen
sudo mkfs.ext4 /dev/debwiki_vg/debwiki_data
# Montar el volumen
sudo mkdir /debwiki_data
sudo mount /dev/debwiki_vg/debwiki_data /debwiki_data
# Montar el volumen cada vez que se inicie el sistema
echo "/dev/debwiki_vg/debwiki_data    /debwiki_data    ext4    defaults    0   0" | sudo tee -a /etc/fstab

# Instalar Apache
sudo apt-get install apache2 -y

# Instalar PHP
sudo apt-get install php7.0 php7.0-mysql libapache2-mod-php7.0 php7.0-xml php7.0-mbstring php7.0-apcu php7.0-intl  php7.0-gd php7.0-cli php7.0-curl -y
# Establecer "upload_max_filesize = 200M"
sudo cp /vagrant/wiki/php.ini /etc/php/7.0/apache2/php.ini

# Reiniciar Apache
sudo systemctl restart apache2

# Instalar MariaDB
sudo apt-get install mariadb-server -y

# Cambiar directorio de almacenamiento de la base de datos al volumen lógico
sudo systemctl stop mariadb
sudo mkdir /debwiki_data/mysql
sudo cp -R -p /var/lib/mysql/* /debwiki_data/mysql
sudo cp /vagrant/wiki/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
sudo chown -R mysql:mysql /debwiki_data/mysql
sudo rm -rf /var/lib/mysql
sudo systemctl start mariadb

# Crear base de datos para la MediaWiki con su usuario
mysql -u root <<-EOF
CREATE DATABASE mediawikidb;
GRANT ALL PRIVILEGES ON mediawikidb.* TO 'mediawikiuser'@'localhost' IDENTIFIED BY 'mediawikipss';
FLUSH PRIVILEGES;
EOF
# Restaurar la base de datos de la MediaWiki vacía (tal como se crea después de una instalación)
mysql -u root mediawikidb < /vagrant/wiki/mediawikidb.sql
# Establecer configuración de seguridad
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('hola') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

# Instalar MediaWiki
wget https://releases.wikimedia.org/mediawiki/1.32/mediawiki-1.32.1.tar.gz
tar -zxvf mediawiki-1.32.1.tar.gz
rm -r mediawiki-1.32.1.tar.gz
sudo mv mediawiki-1.32.1 /var/www/html/mediawiki
# Usuario "ure" contraseña "ureureure"
sudo cp /vagrant/wiki/LocalSettings.php /var/www/html/mediawiki/

# Instalar FileBeat
wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.2.4-amd64.deb
sudo dpkg -i filebeat-6.2.4-amd64.deb
# Establecer logging.selectors: ["*"], entrada logs de Apache y MariaDB, y salida a Logstash
sudo cp /vagrant/wiki/filebeat.yml /etc/filebeat/filebeat.yml
sudo service filebeat start
sudo systemctl enable filebeat

# Mostrar recursos de almacenamiento
df

exit 0
