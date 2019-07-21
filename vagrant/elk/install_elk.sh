#!/bin/bash

# Instalar Prerrequisitos
sudo apt-get update
sudo apt-get install apt-transport-https software-properties-common wget openjdk-8-jdk -y
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
sudo apt-get update

# Instalar LVM2
sudo apt-get install lvm2 -y

# Particionar los discos
sudo sfdisk /dev/sdb < /vagrant/elk/lvm_part_table
sudo sfdisk /dev/sdc < /vagrant/elk/lvm_part_table
sudo sfdisk /dev/sdd < /vagrant/elk/lvm_part_table
sudo sfdisk /dev/sde < /vagrant/elk/lvm_part_table

# Crear los volúmenes físicos
sudo /sbin/pvcreate /dev/sdb1
sudo /sbin/pvcreate /dev/sdc1
sudo /sbin/pvcreate /dev/sdd1
sudo /sbin/pvcreate /dev/sde1

# Crear el volume group
sudo /sbin/vgcreate debelk_vg /dev/sdb1
# Extender el volume group
sudo /sbin/vgextend debelk_vg /dev/sdc1
sudo /sbin/vgextend debelk_vg /dev/sdd1
sudo /sbin/vgextend debelk_vg /dev/sde1
# Crear el volumen lógico en RAID 5
sudo /sbin/lvcreate --type raid5 -l 100%FREE debelk_vg -n debelk_data
# Dar formato al volumen
sudo mkfs.ext4 /dev/debelk_vg/debelk_data
# Montar el volumen
sudo mkdir /debelk_data
sudo mount /dev/debelk_vg/debelk_data /debelk_data
# Montar el volumen cada vez que se inicie el sistema
echo "/dev/debelk_vg/debelk_data    /debelk_data    ext4    defaults    0   0" | sudo tee -a /etc/fstab

# Instalar Elasticsearch
sudo apt-get install elasticsearch -y
# Cambiar directorio de almacenamiento de la base de datos al volumen lógico
sudo systemctl stop elasticsearch
sudo mkdir /debelk_data/elasticsearch
sudo chown -R elasticsearch:elasticsearch /debelk_data/elasticsearch
sudo sed -i 's/path.data: \/var\/lib\/elasticsearch/path.data: \/debelk_data\/elasticsearch/g' /etc/elasticsearch/elasticsearch.yml
# localhost:9200
sudo sed -i 's/#network.host: 192.168.0.1/network.host: localhost/g' /etc/elasticsearch/elasticsearch.yml
sudo sed -i 's/#http.port: 9200/http.port: 9200/g' /etc/elasticsearch/elasticsearch.yml
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch

# Instalar Kibana
sudo apt-get install kibana -y
# localhost:5601
sed -i 's/#server.port: 5601/server.port: 5601/g' /etc/kibana/kibana.yml
sed -i 's/#server.host: "localhost"/server.host: "localhost"/g' /etc/kibana/kibana.yml
sudo systemctl restart kibana
sudo systemctl enable kibana

# Instalar Nginx como reverse proxy
sudo apt-get install nginx -y
# Cambiar password
echo "admin:$(openssl passwd -apr1 hola)" | sudo tee -a /etc/nginx/htpasswd.users
sudo rm -f /etc/nginx/sites-enabled/default
# Puerto 80
sudo cp /vagrant/elk/site-localhost-nginx /etc/nginx/sites-available/localhost
sudo ln -s /etc/nginx/sites-available/localhost /etc/nginx/sites-enabled/localhost
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Instalar Logstash
sudo apt-get install logstash -y
# Entrada Beats y salida Elasticsearch
sudo cp /vagrant/elk/logstash_wiki.conf /etc/logstash/conf.d/logstash_wiki.conf
sudo systemctl restart logstash
sudo systemctl enable logstash

# Mostrar recursos de almacenamiento
df

exit 0
