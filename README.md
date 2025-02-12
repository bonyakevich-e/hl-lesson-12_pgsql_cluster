### OTUS High Load Lesson #17 | Subject: Реализация кластера postgreSQL с помощью Patroni
--------------------
### ЦEЛЬ: Перевести БД веб проекта на кластер postgreSQL с ипользованием patroni, etcd/consul/zookeeper и haproxy/pgbouncer
--------------------
#### ВЫПОЛНЕНИЕ:
Схема стенда:

![otus highload scheme v5 patroni](https://github.com/user-attachments/assets/c9d2c5cf-5e02-4290-b2a5-425ee125c8b1)

Стенд собирается с помощью команд:
```
$ terraform init
$ ansible-playbook -i hosts playbook.yml
```
В итоге имеем:
1. Кластер ETCD из трёх нод. Распределенное хранилище конфигураций, требуется для работы Patroni:
   
![image](https://github.com/user-attachments/assets/543efcf8-9c98-4121-b8f7-e5a3336143f6)

2. Кластер PostgreSQL из двух нод. Кластер собирается с помощью Patroni:

![image](https://github.com/user-attachments/assets/e3bcc4fe-1f48-4951-92ac-b27fb3562bae)

3. Сервер с установленым сервисом Nextcloud. На этом же сервере установлен HAProxy, который следить за состоянием PostgreSQL-кластера и проксирует запросы от Nextcloud на primary ноду баз данных. В HAProxy настроено два бэкенда: "primary" слушает на порту *:5000 и проксирует запросы на primary ноду; "standby" слушает на порту *:5001 и проксирует запросы на replica. Таким образом, при необходимости (и если это поддерживается со стороны клиента) можно запросы на чтение/запись отправлять на primary ноду, и дополнительно запросы на чтение отправлять на реплику:

![image](https://github.com/user-attachments/assets/7897223a-326d-49cd-aff8-de3e5387cbef)

При падении одного из серверов баз данных, лидером становится второй:

![image](https://github.com/user-attachments/assets/c1e28646-6b9d-4adf-9b57-b554736186a7)

HAProxy начинает пересылать запросы на database2:

![image](https://github.com/user-attachments/assets/6d5ef9d2-b052-4039-855e-fde7396eaa16)

Сервис Nextcloud продолжает работать:

![image](https://github.com/user-attachments/assets/7a18cba8-b3da-488f-9373-67a36c5690b3)
