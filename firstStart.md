Вот подробная версия в формате Markdown. Можешь просто заменить содержимое `firstStart.md` на это.

````markdown
# Первый запуск TreeD MainshellOS на чистой плате

Документ описывает **полный путь** от свежей microSD с MainsailOS до полностью настроенной платы TreeD:

- единые логин/пароль;
- единое имя хоста (`treedos`);
- локаль и часовой пояс (Volgograd);
- подготовленный каталог конфигов `/home/pi/treed`;
- автоподтяжка репозитория `treed-mainshellOS` с GitHub и запуск `loader.sh` из него;
- готовность к дальнейшей работе только через Git (никаких ручных правок на плате).

Документ расчитан на то, что действия выполняет технарь/оператор, который **умеет пользоваться SSH**, но не обязан помнить все команды наизусть — всё есть ниже.

---

## Термины по ходу

Чтобы не путаться:

- **hostname** — имя устройства в сети, то, что видно в приглашении терминала (`pi@treedos:~ $`) и в списке устройств.
- **locale** — локаль, набор настроек языка + формат времени/дат/чисел.
- **timezone** — часовой пояс (например, `Europe/Volgograd`).
- **репозиторий (repo)** — проект на GitHub; здесь это `treed-mainshellOS`.
- **loader.sh** — скрипт внутри репозитория, который применяет тему загрузчика, тему Mainsail и другие настройки.
- **симлинк (symbolic link)** — “ярлык” на папку/файл. Мы используем его, чтобы `/home/pi/printer_data/config` “указывал” на `/home/pi/treed`.

---

## 0. Подготовка microSD

1. Скачиваем актуальный образ **MainsailOS** для Raspberry Pi.
2. Записываем образ на microSD (через Raspberry Pi Imager / balenaEtcher и т.п.).
3. Вставляем microSD в плату.
4. Подключаем:
   - экран;
   - клавиатуру;
   - питание.

После включения Raspberry Pi загрузится в системную консоль.

---

## 1. Первый вход и настройка Wi-Fi

### 1.1. Вход на локальной консоли

На экране появится приглашение:

```text
raspberrypi login:
````

или похожее (может быть `mainsailos login:`).

Вводим:

* **Login**: `pi`
* **Password**: `raspberry`
  (это дефолтный пароль MainsailOS, мы его позже сменим скриптом).

Попадаем в консоль:

```text
pi@mainsailos:~ $
```

или схожее.

### 1.2. Настройка Wi-Fi через `raspi-config`

Команда:

```bash
sudo raspi-config
```

Откроется текстовое меню:

1. Выбираем пункт **System Options**.
2. Далее **Wireless LAN**.
3. Вводим:

   * SSID — имя вашей Wi-Fi сети;
   * пароль — пароль от Wi-Fi.

Выходим через **Finish**. Если `raspi-config` предложит **перезагрузиться** — соглашаемся.

После перезагрузки **ещё раз** входим локально (опять `pi` / `raspberry`).

---

## 2. Узнать IP адрес платы

Теперь надо узнать IP, чтобы подключаться по SSH с компьютера.

В консоли Raspberry Pi:

```bash
hostname -I
```

Пример вывода:

```text
192.168.0.195
```

Это IP платы в локальной сети. Запоминаем/записываем.

---

## 3. Подключение по SSH с рабочего компьютера

Дальнейшая настройка будет через SSH (удаленная консоль).

### 3.1. Подключение из Windows PowerShell

На ПК открываем PowerShell и выполняем:

```powershell
ssh pi@192.168.0.195
```

(подставь **свой** IP вместо `192.168.0.195`).

При первом подключении:

* появится вопрос про доверие к ключу хоста;
* пишем `yes` и жмём Enter;
* запрашивается пароль — пока **старый дефолтный**: `raspberry`.

Если уже раньше подключались к этому IP и получаете ошибку:

```text
REMOTE HOST IDENTIFICATION HAS CHANGED!
```

то:

```powershell
ssh-keygen -R 192.168.0.195
ssh pi@192.168.0.195
```

и снова `yes`, `raspberry`.

При успешном входе увидим в консоли что-то вроде:

```text
pi@mainsailos:~ $
```

---

## 4. Единственный большой стартовый скрипт TreeD

Этот скрипт:

* приводит систему к единому стандарту TreeD;
* устанавливает/обновляет базовые пакеты;
* настраивает hostname, локаль, часовой пояс;
* переустанавливает KlipperScreen;
* создаёт `/home/pi/treed` и симлинк `/home/pi/printer_data/config -> /home/pi/treed`;
* подтягивает старый `moonraker.conf` (если он был в образе);
* включает SSH, SPI, I2C, UART и расширяет файловую систему;
* **клонирует репозиторий** `treed-mainshellOS` в `.staging`;
* запускает `loader/loader.sh` из репозитория, который ставит тему загрузчика и тему Mainsail.

> ⚠️ Важно: скрипт нужно запускать **одним куском**, не по частям.

В том же SSH-сеансе вставляем **полностью**:

```bash
sudo -s <<'EOF'
set -e
apt-get update
apt-get -y full-upgrade
timedatectl set-timezone Europe/Volgograd
sed -i 's/^# *ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=ru_RU.UTF-8
hostnamectl set-hostname treedos
if grep -q '^127\.0\.1\.1' /etc/hosts; then
sed -i 's/^127\.0\.1\.1.*/127.0.1.1 treedos/' /etc/hosts
else
printf '\n127.0.1.1 treedos\n' >> /etc/hosts
fi
echo 'pi:treed' | chpasswd
CFG=$( [ -e /boot/firmware/config.txt ] && echo /boot/firmware/config.txt || echo /boot/config.txt )
grep -q 'hdmi_cvt=960 544 60' "$CFG" || cat >>"$CFG" <<EOC
hdmi_group=2
hdmi_mode=87
hdmi_cvt=960 544 60 6 0 0 0
hdmi_drive=2
disable_overscan=1
dtparam=i2c_arm=on
dtparam=spi=on
EOC
grep -q 'consoleblank=0' /boot/cmdline.txt || sed -i '1 s/$/ consoleblank=0/' /boot/cmdline.txt
apt-get -y install git unzip dfu-util screen python3-gi python3-gi-cairo libgtk-3-0 xserver-xorg x11-xserver-utils xinit openbox python3-numpy python3-scipy python3-matplotlib i2c-tools python3-venv rsync
for grp in dialout tty video input render plugdev gpio i2c spi; do
getent group "$grp" >/dev/null 2>&1 && usermod -aG "$grp" pi || true
done
cd /home/pi
[ -d KlipperScreen ] && rm -rf KlipperScreen
git clone https://github.com/jordanruthe/KlipperScreen.git
cd KlipperScreen
./scripts/KlipperScreen-install.sh
systemctl enable KlipperScreen.service
mkdir -p /home/pi/treed
mkdir -p /home/pi/treed/.staging
chown -R pi:pi /home/pi/treed
if [ -d /home/pi/printer_data/config ] && [ ! -L /home/pi/printer_data/config ]; then mv /home/pi/printer_data/config /home/pi/printer_data/config.bak.$(date +%s); fi
[ -L /home/pi/printer_data/config ] || ln -s /home/pi/treed /home/pi/printer_data/config
if ls /home/pi/printer_data/config.bak.*/moonraker.conf >/dev/null 2>&1; then
cp /home/pi/printer_data/config.bak.*/moonraker.conf /home/pi/treed/
fi
if command -v raspi-config >/dev/null 2>&1; then
raspi-config nonint do_ssh 0
raspi-config nonint do_spi 0
raspi-config nonint do_i2c 0
raspi-config nonint do_serial 2
raspi-config nonint do_expand_rootfs
fi
STAGING_DIR="/home/pi/treed/.staging"
REPO_DIR="$STAGING_DIR/treed-mainshellOS"
mkdir -p "$STAGING_DIR"
rm -rf "$REPO_DIR"
git clone https://github.com/Yawllen/treed-mainshellOS.git "$REPO_DIR"
chmod +x "$REPO_DIR/loader/loader.sh"
"$REPO_DIR/loader/loader.sh"
EOF
sudo reboot
```

### Краткий разбор, что делает скрипт

По блокам:

1. `set -e`
   Если любая команда падает с ошибкой — скрипт останавливается. Это защищает от “тихих” поломок.

2. Обновления и локаль:

   * `apt-get update && full-upgrade` — система обновлена.
   * Часовой пояс `Europe/Volgograd`.
   * Локали `ru_RU.UTF-8` и `en_US.UTF-8` включены, по умолчанию `ru_RU.UTF-8`.

3. Имя хоста и `/etc/hosts`:

   * `hostnamectl set-hostname treedos` — новое имя системы.
   * В `/etc/hosts`:

     * если есть строка `127.0.1.1 ...` — заменяется на `127.0.1.1 treedos`;
     * иначе добавляется новая строка.
   * Это убирает ошибку `sudo: unable to resolve host treedos`.

4. Пароль:

   * `echo 'pi:treed' | chpasswd` — теперь:

     * логин: `pi`
     * пароль: `treed`.

5. Экран:

   * Выбор `config.txt` (учёт разных путей в разных образах).
   * Если ещё нет `hdmi_cvt=960 544 60`, добавляется блок:

     * параметры HDMI для твоего экрана;
     * включение `i2c_arm` и `spi`.
   * В `cmdline.txt` добавляется `consoleblank=0`, чтобы экран не гас во время загрузки.

6. Пакеты и группы:

   * Ставятся все нужные пакеты (git, Xorg, GTK, python, rsync и т.п.).
   * В цикле пользователь `pi` добавляется в группы:

     * `dialout`, `tty`, `video`, `input`, `render`, `plugdev`, `gpio`, `i2c`, `spi` — **только если группа есть в системе** (иначе пропускаем).

7. KlipperScreen:

   * Удаляется старый `KlipperScreen` в `/home/pi`, если он был.
   * Клонируется свежий из GH `jordanruthe/KlipperScreen`.
   * Запускается его инсталлятор.
   * Сервис `KlipperScreen.service` включается в автозагрузку.

8. Наш каталог `/home/pi/treed`:

   * Создаётся `/home/pi/treed` и `/home/pi/treed/.staging`.
   * Права владельца `pi:pi`.
   * Если `/home/pi/printer_data/config` — обычная папка:

     * она переименовывается в `config.bak.<timestamp>`.
   * Если `/home/pi/printer_data/config` ещё не симлинк:

     * создаётся симлинк на `/home/pi/treed`.
   * Если в любом `config.bak.*` есть `moonraker.conf`:

     * копируется в `/home/pi/treed/`, чтобы Moonraker мог стартовать без ручной настройки.

9. `raspi-config` без интерфейса:

   * Если команда `raspi-config` есть:

     * включается SSH;
     * включается SPI и I2C;
     * настраивается UART так, чтобы порт был свободен под связи с МК;
     * расширяется файловая система под весь размер карты.

10. Подтягивание `treed-mainshellOS` и запуск `loader.sh`:

    * В `/home/pi/treed/.staging`:

      * создаётся каталог, удаляется старый `treed-mainshellOS` (если был);
      * клонируется репозиторий `https://github.com/Yawllen/treed-mainshellOS.git`.
    * Скрипт `loader/loader.sh` делается исполняемым и запускается.
    * Внутри `loader.sh` (в репозитории) уже описано:

      * установка plymouth и темы загрузчика `treed`;
      * разворачивание Mainsail темы `.theme`;
      * применение дополнительных системных настроек (если добавлены в репо).

11. Перезагрузка:

    * `sudo reboot` — плата перезагружается уже в состоянии `treedos` с нашими настройками.

---

## 5. Состояние системы после перезагрузки

После выполнения скрипта и ребута:

* Имя хоста: `treedos`.

* Логин по SSH:

  ```bash
  ssh pi@IP_ПЛАТЫ
  ```

  пароль — `treed`.

* KlipperScreen установлен и запускается как сервис.

* Moonraker настроен (если был `moonraker.conf` в штатном образе — он перенесён).

* Все конфиги лежат в `/home/pi/treed`:

  * `/home/pi/printer_data/config` теперь **симлинк** на `/home/pi/treed`.

* Репозиторий `treed-mainshellOS` лежит в:

  ```text
  /home/pi/treed/.staging/treed-mainshellOS
  ```

* Загрузчик (Plymouth) и Mainsail тема подтянуты и применены через `loader/loader.sh`.

---

## 6. Как обновлять систему после изменений в Git

Когда ты меняешь что-то в репозитории `treed-mainshellOS` (локально в VS Code → `git commit` → `git push`), на плате достаточно:

```bash
ssh pi@IP_ПЛАТЫ
# пароль treed

cd /home/pi/treed/.staging/treed-mainshellOS
git pull
chmod +x loader/loader.sh
./loader/loader.sh
```

Что происходит:

1. `git pull` подтягивает свежую ветку `main` с GitHub.
2. `loader.sh` снова:

   * разворачивает тему загрузчика;
   * обновляет `.theme` Mainsail;
   * применяет всё остальное, что описано в репозитории.

Таким образом, после первого «большого» запуска тебе не нужно перепрошивать плату или выполнять сложные команды — всё развитие UI/тем/загрузчика живёт в репозитории, а на плате достаточно `git pull + loader.sh`.

```
::contentReference[oaicite:0]{index=0}
```
