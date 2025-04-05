
function init {
    function installdmg {
        DMG_URL="$1"
        DMG_FILE="$(basename "$DMG_URL")"
        INSTALL_DIR="/opt/goinfre/$(whoami)"
        LINK_PATH="/Users/$(whoami)/Applications"

        # Скачиваем .dmg файл
        curl "$DMG_URL" -L -o "$DMG_FILE"
        if [ $? -ne 0 ]; then
            echo "Ошибка при скачивании файла."
            return 1;
        fi

        # Создаем папку для установки, если её нет
        mkdir -p "$INSTALL_DIR"

        # Монтируем .dmg файл
        MOUNT_POINT="/Volumes/temp-mount"
        hdiutil attach "$DMG_FILE" -nobrowse -mountpoint "$MOUNT_POINT"
        if [ $? -ne 0 ]; then
            echo "Ошибка при монтировании .dmg файла."
            return 1;
        fi

        # Определяем имя приложения
        APP_NAME=$(ls "$MOUNT_POINT" | grep ".app$")
        if [ -z "$APP_NAME" ]; then
            echo "Приложение не найдено внутри .dmg файла."
            hdiutil detach "$MOUNT_POINT"
            return 1;
        fi

        # Копируем приложение в INSTALL_DIR
        cp -R "$MOUNT_POINT/$APP_NAME" "$INSTALL_DIR"
        hdiutil detach "$MOUNT_POINT"
        if [ $? -ne 0 ]; then
            echo "Ошибка при демонтаже .dmg файла."
            return 1;
        fi

        # Удаляем .dmg файл
        rm "$DMG_FILE"

        # Создаем символическую ссылку
        ln -s "$INSTALL_DIR/$APP_NAME" "$LINK_PATH/$APP_NAME"
        if [ $? -ne 0 ]; then
            echo "Ошибка при создании символической ссылки."
        fi

        echo "Установка завершена. $APP_NAME установлен в $INSTALL_DIR."
    }

    if [ "$1" = "-java" ]; then
      brew install maven
      brew install openjdk
    fi
    
    if [ "$1" = "-qt" ]; then
      installdmg "https://qt-mirror.dannhauer.de/archive/qtcreator/7.0/7.0.0/qt-creator-opensource-mac-x86_64-7.0.0.dmg"
      echo "Установка завершена. Qt Creator установлен в $INSTALL_DIR.\nВ настройках укажите путь до /usr/local/Qt-6.6.2/bin/qmake6"
    fi

    if [ "$1" = "-tor" ]; then
        echo "Поиск последней стабильной версии Tor Browser..."
        TOR_MIRROR="https://tor.zilog.es/dist/torbrowser/"
        LATEST_VERSION=$(curl -s "$TOR_MIRROR" | grep -o 'href="[0-9]\+\.[0-9]\+\.[0-9]\+/\?"' | sort -V | tail -1 | sed 's/href="//;s/\/"//')
        
        if [ -z "$LATEST_VERSION" ]; then
            echo "Не удалось определить последнюю версию Tor Browser."
            return 1
        fi

        TOR_URL="${TOR_MIRROR}${LATEST_VERSION}/tor-browser-macos-${LATEST_VERSION}.dmg"
        echo "Найдена последняя версия: $LATEST_VERSION"
        echo "Ссылка для скачивания: $TOR_URL"
        
        installdmg "$TOR_URL"
    fi

    if [ "$1" = "-install" ]; then
        installdmg "$2"
    fi
}

function push {
  cd $(pwd)
  find . -type f  -name *.c -name *.cc -o -name *.h -o -name *.cpp | xargs clang-format -style='{BasedOnStyle: Google}' -i

  branch=$(git rev-parse --abbrev-ref HEAD)
  commit="backup"

  for arg in "$@"; do
      if [ "$arg" = "-d" ]; then
            branch="develop"
            git checkout -b $branch
            git checkout $branch
      else
          commit=$arg
      fi
  done

  git add --all
  git commit -m $commit
  git push --set-upstream origin $branch
}

function code {
  open -a 'Visual Studio Code' $1
}

function help {
  open -a Safari https://github.com/macygabr/ZprofileForMac
}

function check {
  if [ -n "$1" ]; then
    echo -e '\033[32mClone\033[0m'
    git clone "$1"
    if [ $? -ne 0 ]; then
      echo -e '\033[31mОшибка: не удалось клонировать репозиторий\033[0m'
      return 1
    fi

    REPO_NAME=$(echo "$1" | awk -F / '{print $NF}' | sed -r 's/.git+//')
    cd "$REPO_NAME" || { echo -e '\033[31mОшибка: не удалось перейти в директорию $REPO_NAME\033[0m'; return 1; }

    git checkout develop
    if [ $? -ne 0 ]; then
      echo -e '\033[31mОшибка: не удалось переключиться на ветку develop\033[0m'
      return 1
    fi

    code .
  fi

  echo -e '\033[32mCheck clang-format\033[0m'
  cd src || { echo -e '\033[31mОшибка: директория src не найдена\033[0m'; return 1; }

  cp ../materials/linters/.clang-format .
  if [ $? -ne 0 ]; then
    echo -e '\033[31mОшибка: не удалось скопировать .clang-format\033[0m'
    return 1
  fi

  clang-format -n $(find . -type f -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.cc")
  if [ $? -ne 0 ]; then
    echo -e '\033[31mОшибка: проблемы с clang-format\033[0m'
    return 1
  fi
  rm -rf .clang-format

  echo -e '\033[32mCpp check\033[0m'

  FILES=$(find . -type f \( -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.cc" \))

  if [ -n "$FILES" ]; then
    echo "$FILES" | xargs cppcheck --enable=all --suppress=missingIncludeSystem
    if [ $? -ne 0 ]; then
      echo -e '\033[31mОшибка: проблемы с cppcheck\033[0m'
      return 1
    fi
  else
    echo -e '\033[33mПредупреждение: файлы для анализа cppcheck не найдены\033[0m'
  fi
  return 0
}

function clean {
# Colors
blue=$'[0;34m'
cyan=$'[1;96m'
reset=$'[0;39m'
green=$'[0;32m'
red=$'[0;31m'
# Initial total space, used and available
echo "$cyan"'----|Before cleanup|----|'
echo "$blue"'Size  '"$cyan"'|  '"$red"'Used  '"$cyan"'|  '"$green"'Avail '"$cyan"'|'"$reset"
df -h | grep Users | awk -v cyan="$cyan" -v green="$green" -v blue="$blue" -v red="$red" '{print blue $2 " "cyan"=  " red $3 cyan" +  "  green $4 " "cyan"|"}'
echo -n "$reset"

# Cleanup...
rm -rf ~/.kube/cache/\* 2>/dev/zero
rm -rf ~/.Trash/\* 2>/dev/zero
rm -rf ~/Library/42_cache/ 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/Cache/Library/Application\ Support/Code/Cachei 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/CacheData 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/CachedData 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/CachedExtension 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/CachedExtensions 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/Crashpad/completed 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/User/workspaceStorage 2>/dev/zero
rm -rf ~/Library/Application\ Support/Firefox/Profiles/hdsrd79k.default-release/storage 2>/dev/zero
rm -rf ~/Library/Application\ Support/Slack/Cache/ 2>/dev/zero
rm -rf ~/Library/Application\ Support/Slack/Code\ Cache/ 2>/dev/zero
rm -rf ~/Library/Application\ Support/Slack/Service\ Worker/CacheStorage/ 2>/dev/zero
rm -rf ~/Library/Application\ Support/Spotify/PersistentCache 2>/dev/zero
rm -rf ~/Library/Application\ Support/Telegram\ Desktop/tdata/emoji 2>/dev/zero
rm -rf ~/Library/Application\ Support/Telegram\ Desktop/tdata/user_data 2>/dev/zero
rm -rf ~/Library/Caches/ 2>/dev/zero
rm -rf ~/Library/Containers/com.docker.docker/Data/vms/\* 2>/dev/zero
rm -rf ~/Library/Group\ Containers/6N38VWS5BX.ru.keepcoder.Telegram/account-570841890615083515/postbox/\* 2>/dev/zero
# betatest cleanup
rm -rf ~/Library/Application\ Support/Code/CachedExtensionVSIXs 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/CachedProfilesData 2>/dev/zero
rm -rf ~/Library/Application\ Support/Code/logs 2>/dev/zero
rm -rf ~/Library/Application\ Support/discord/Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/discord/Code\ Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/discord/Crashpad 2>/dev/zero
rm -rf ~/Library/Application\ Support/discord/VideoDecodeStats 2>/dev/zero
rm -rf ~/Library/Application\ Support/GitKraken/Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/GitKraken/Code\ Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/GitKraken/Crashpad 2>/dev/zero
rm -rf ~/Library/Application\ Support/GitKraken/CrashReports 2>/dev/zero
rm -rf ~/Library/Application\ Support/Google/Chrome/Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Service\ Worker/CacheStorage 2>/dev/zero
rm -rf ~/Library/Application\ Support/Google/Chrome/Snapshots 2>/dev/zero
rm -rf ~/Library/Application\ Support/jazz/Code\ Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/jazz/Crashpad 2>/dev/zero
rm -rf ~/Library/Application\ Support/jazz/WebrtcVideoStats 2>/dev/zero
rm -rf ~/Library/Application\ Support/Postman/Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/Postman/Partitions 2>/dev/zero
rm -rf ~/Library/Application\ Support/Rocket.Chat/Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/Rocket.Chat/Partitions/https%3A/rocketchat-student.21-school.ru/Cache/Cache_Data 2>/dev/zero
rm -rf ~/Library/Application\ Support/Yandex/YandexBrowser/Cache 2>/dev/zero
rm -rf ~/Library/Application\ Support/Yandex/YandexBrowser/Default/Service\ Worker/CacheStorage 2>/dev/zero
rm -rf ~/Library/Application\ Support/Yandex/YandexBrowser/Snapshots 2>/dev/zero
rm -rf ~/Library/Application\ Support/zoom.us/Cache 2>/dev/zero

# Space after cleanup
echo "$cyan"'----|After  cleanup|----|'
echo "$blue"'Size  '"$cyan"'|  '"$red"'Used  '"$cyan"'|  '"$green"'Avail '"$cyan"'|'"$reset"
df -h | grep Users | awk -v cyan="$cyan" -v green="$green" -v blue="$blue" -v red="$red" '{print blue $2 " "cyan"=  " red $3 cyan" +  "  green $4 " "cyan"|"}'
echo -n "$reset"
echo "$cyan"'----|Cleanup  ended|----|'
}

function wttr {
curl "https://wttr.in/Novosibirsk?lang=ru"
}

function freln {
  local src_path=$1
  local goinfre_folder=${2:-"links"}  # Если второй аргумент не указан, присваиваем "links"
  local goinfre_path=~/goinfre/$goinfre_folder/$(basename "$src_path")  # Перемещаем саму папку

  # Проверяем, что первый аргумент (путь до папки) передан
  if [ -z "$src_path" ]; then
    echo "Usage: freln <source_path> [goinfre_subfolder]"
    return 1
  fi

  # Создаем целевую папку в goinfre, если она ещё не существует
  mkdir -p "$(dirname "$goinfre_path")"

  # Если исходная папка существует, перемещаем её в goinfre
  if [ -d "$src_path" ]; then
    mv "$src_path" "$goinfre_path"
  fi

  # Создаем символическую ссылку на новое местоположение
  ln -s "$goinfre_path" "$src_path"

  echo "Moved $src_path to $goinfre_path and created a symlink"
}

function dockerln {
  rm -rf ~/Library/Containers/com.docker.docker
  mkdir -p ~/goinfre/Docker/Data
  ln -s ~/goinfre/Docker ~/Library/Containers/com.docker.docker
}


function sql {
# Colors
cyan=$'[1;96m'
green=$'[0;32m'
red=$'[0;31m'

for arg in "$@"; do
  if [ "$arg" = "-c" ]; then
    local num_folders=$1
    local base_folder="ex"
    local confirmation
    local day_num

    echo "$cyan"'How many folders do you need?'
    read num_folders

    echo "$cyan"'Which is the day of SQL do you do?'
    read day_num
    # Запрашиваем подтверждение от пользователя
    echo "$cyan"'Are you sure you want to create' "$num_folders" 'new sql-folders for the day:' "$day_num"'? Y/n'
    read confirmation

    # Проверяем ввод пользователя
    case $confirmation in
      [Yy]* )
        # Продолжаем выполнение, так как пользователь ввел "y"
        ;;
      [Nn]* )
        echo "$cyan"'Command cancelled.'
        return 0
        ;;
      * )
        echo "$red"'Invalid input.'
        return 1
        ;;
    esac

    # Создаем нужное количество папок
    for (( j = 0; j < num_folders; j++ )); do
      if [ $j -le 9 ]; then
        mkdir "${base_folder}0$j"
      else
        mkdir "${base_folder}$j"
      fi
    done

    # Переходим в каждую папку и создаем файлы
    for (( i = 0; i < num_folders; i++ )); do
      if [ $i -le 9 ]; then
        cd "${base_folder}0$i"
        if [ $day_num -le 9 ]; then
             touch "day0${day_num}_${base_folder}0$i.sql"
        else
             touch "day${day_num}_${base_folder}0$i.sql"
        fi
        cd ../
      else
        cd "${base_folder}$i"
        if [ $day_num -le 9 ]; then
             touch "day0${day_num}_${base_folder}$i.sql"
        else
             touch "day${day_num}_${base_folder}$i.sql"
        fi
        cd ../
      fi
    done
    echo "$green""$num_folders" 'sql-folders for the day:' "$day_num" '- created successfully'
    fi
    done

    if [ "$arg" = "-d" ]; then
        # Подсчет количества папок, соответствующих шаблону
      # count=$(ls | grep '^ex*' | wc -l)
      # count=$(ls | grep '^ex[[:alnum:]_]\{2\}[0-9]\{2\}$' | wc -l)
      count=$(ls | grep '^ex[0-9]\{2\}$' | wc -l)

      # Проверка наличия папок
      if [[ count -gt 0 ]]; then
        echo "$cyan"'Are you sure you want to delete these folders in count about:' "$count"'? (y/n)'
        read answer

        if [[ $answer == y ]]; then
          rm -rf ex[0-9][0-9]
          echo "$green""$count" 'folders deleted successfully.'
        elif [[ $answer == n ]]; then
          echo "$cyan"'Operation cancelled.'
        else
          echo "$red"'Invalid input. Operation is cancelled.'
        fi
      else
        echo "$red"'No any folders to delete.'
      fi
    fi
}


#Default update
curl --silent https://raw.githubusercontent.com/macygabr/ZprofileForMac/main/.zprofile > ~/.zprofile

#Default clean
clean > /dev/null

#Default install homebrew
if [ -d /opt/goinfre/$(whoami)/homebrew ];
then
 eval "$(/opt/goinfre/$(whoami)/homebrew/bin/brew shellenv)"
 chmod -R go-w "$(brew --prefix)/share/zsh"
else
 cd /opt/goinfre/$(whoami)
 git clone https://github.com/Homebrew/brew homebrew
 eval "$(/opt/goinfre/$(whoami)/homebrew/bin/brew shellenv)"
 brew update --force --quiet
 chmod -R go-w "$(brew --prefix)/share/zsh"
 brew install lcov
fi
