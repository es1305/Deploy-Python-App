# Деплой приложений. Python

## 1. Установка менеджера версий Python

Используем [pyenv](https://github.com/pyenv/pyenv).
Для начала установим [файлы](https://github.com/pyenv/pyenv/wiki#suggested-build-environment), необходимые для установки Python:

```bash
apt install -y make build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
libffi-dev liblzma-dev
```

Установка [pyenv](https://github.com/pyenv/pyenv#installation):

```bash
git clone https://github.com/pyenv/pyenv.git ~/.pyenv
cd ~/.pyenv && src/configure && make -C src
```

Настройка переменных окружения:

```bash
sed -Ei -e '/^([^#]|$)/ {a \
export PYENV_ROOT="$HOME/.pyenv"
a \
export PATH="$PYENV_ROOT/bin:$PATH"
a \
' -e ':a' -e '$!{n;ba};}' ~/.profile

echo 'eval "$(pyenv init --path)"' >>~/.profile
echo 'eval "$(pyenv init -)"' >>~/.bashrc
```

Перелогинимся для применения.

Для управления виртуальными окружениями Python установим модуль [pyenv-virtualenv](https://github.com/pyenv/pyenv-virtualenv):

```bash
git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
source ~/.bashrc
```

## 2. Установка Python и подготовка приложения

Приложение будем размещать в папке `/var/www/app`, поэтому установим заодно `nginx`:

```bash
apt install -y nginx
git clone https://github.com/gothinkster/django-realworld-example-app /var/www/app
```

Установим нужную версию Python, создадим виртуальное окружение и назначим его папке нашего приложения:

```bash
pyenv install 3.5.10
pyenv virtualenv 3.5.10 app
cd /var/www/app/ && pyenv local app
```

Соберём зависимости проекта:

```bash
pip install -r requirements.txt
```

## 3. Установка и настройка СУБД

По заданию у нас PostgreSQL:

```bash
apt install -y postgresql
```

Настроим доступ для локальных пользователей:

```bash
vi /etc/postgresql/12/main/pg_hba.conf
```

```bash
# Database administrative login by Unix domain socket
local   all             postgres                                trust
# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
```

```bash
systemctl restart postgresql
```

Создадим пользователя БД и базу:

```bash
sudo -u postgres createuser -d django
createdb -U django django
```

Установим библиотеки для взаимодействия с Python:

```bash
apt install libpq-dev
pip install psycopg2
```

Добавим следующие исправления в `settings.py`:

```bash
ALLOWED_HOSTS = ['*']

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'django',
        'USER': 'django',
        'HOST': '127.0.0.1',
        'PORT': '5432',
    }
}

STATIC_ROOT = '/var/www/static'
```

после чего выполним миграции и генерацию статики:

```bash
python manage.py migrate
python manage.py collectstatic
```

## 4. Настройка WSGI

В папке приложения:

```bash
pip install uwsgi
```

Добавим сервис для автоматического запуска `wsgi`:

```bash
vi /etc/systemd/system/uwsgi.service
```

```bash
[Unit]
Description=uWSGI instance to serve Django app

[Service]
ExecStartPre=-/usr/bin/bash -c 'mkdir -p /run/uwsgi; chown www-data:www-data /run/uwsgi'
ExecStart=/usr/bin/bash -c 'cd /var/www/app; /root/.pyenv/shims/uwsgi --ini wsgi_app.ini'

[Install]
WantedBy=multi-user.target
```

Настройки для взаимодействия с приложением:

```bash
vi wsgi_app.ini 
```

```bash
[uwsgi]
module = conduit.wsgi

master = true
processes = 5

uid = root
socket = /run/uwsgi/wsgi_app.sock
chown-socket = www-data:www-data
chmod-socket = 660
vacuum = true

die-on-term = true
```

Включение, запуск и проверка сервиса:

```bash
systemctl daemon-reload
systemctl enable uwsgi
systemctl start uwsgi
systemctl status uwsgi
```

## 5. Запуск приложения в `http`-режиме

Настроим сайт для нашего приложения:

```bash
vi /etc/nginx/sites-available/es1305-www-1.devops.rebrain.srwx.net
```

```bash
server {
        listen 80 default_server;

        index index.html index.htm index.nginx-debian.html;

        server_name es1305-www-1.devops.rebrain.srwx.net;

        location / {
            include uwsgi_params;
            uwsgi_pass unix:/run/uwsgi/wsgi_app.sock;
        }

        location /static/ {
            alias /var/www/static/;
        }
}
```

Включим наш сайт и отключим сайт по умолчанию `nginx`:

```bash
ln -s /etc/nginx/sites-available/es1305-www-1.devops.rebrain.srwx.net /etc/nginx/sites-enabled/
```

```bash
rm /etc/nginx/sites-enabled/default
```

Проверим и перезагрузим `nginx`:

```bash
chown -R www-data:www-data /var/www
nginx -t
nginx -s reload
```

## 6. Запуск приложения в `https`-режиме

Используем [certbot](https://certbot.eff.org) для получения сертификата Let’s Encrypt и автоматической настройки `nginx`:

```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d es1305-www-1.devops.rebrain.srwx.net
nginx -t
nginx -s reload
```
