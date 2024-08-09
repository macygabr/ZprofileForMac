
function init {
    function qtinstall {
        # Путь к .dmg файлу
        DMG_URL="https://qt-mirror.dannhauer.de/archive/qtcreator/7.0/7.0.0/qt-creator-opensource-mac-x86_64-7.0.0.dmg"
        # Имя .dmg файла
        DMG_FILE="qt-creator-opensource-mac-x86_64-7.0.0.dmg"
        # Папка для установки
        INSTALL_DIR="/opt/goinfre/$(whoami)"
        # Путь для символической ссылки в /Applications
        LINK_PATH="/Users/$(whoami)/Applications"

        # Скачиваем .dmg файл
        curl "$DMG_URL" -L -o "$DMG_FILE"
        # Проверка успешности загрузки
        if [ $? -ne 0 ]; then
            echo "Ошибка при скачивании файла."
            return 1
        fi

        # Создаем папку для установки, если её нет
        mkdir -p "$INSTALL_DIR"
        # Монтируем .dmg файл
        hdiutil attach "$DMG_FILE" -nobrowse -mountpoint /Volumes/qt-creator
        # Проверка успешности монтирования
        if [ $? -ne 0 ]; then
            echo "Ошибка при монтировании .dmg файла."
            return 1
        fi

        cp -R /Volumes/qt-creator/Qt\ Creator.app "$INSTALL_DIR"
        hdiutil detach /Volumes/qt-creator
        if [ $? -ne 0 ]; then
            echo "Ошибка при демонтаже .dmg файла."
            return 1
        fi

        rm "$DMG_FILE"
        ln -s "$INSTALL_DIR/Qt Creator.app" "$LINK_PATH/Qt Creator.app"
        if [ $? -ne 0 ]; then
            echo "Ошибка при создании символической ссылки."
            return 1
        fi

        echo "Установка завершена. Qt Creator установлен в $INSTALL_DIR.\nВ настройках укажите путь до /usr/local/Qt-6.6.2/bin/qmake6"
    }

    if [ "$1" = "-java" ]; then
      brew install maven
      brew install openjdk
    fi
    
    if [ "$1" = "-qt" ]; then
      qtinstall
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
  DARKYELLOW="\033[33m"
  BLUE=$'\033[0;34m'
  GREEN=$'\033[0;32m'
  END="\033[0m"

  printf "\n\t\t${GREEN}Welcome!${END}\n"
  printf "\tNow you can use the following functions:\n"

  printf "\n${BLUE}init (-flag)${DARKYELLOW}\t\t\t Initializes environment based on the specified flag:${END}\n"
  printf "\t\t${BLUE}-java${DARKYELLOW}\t\t Installs Openjdk@22 and Maven.\n\t\t\t\t Example: init -java${END}\n"
  printf "\t\t${BLUE}-qt${DARKYELLOW}\t\t Downloads and installs Qt Creator to /opt/goinfre/\$(whoami) and creates a symbolic link in /Users/\$(whoami)/Applications.\n\t\t\t\t Example: init -qt${END}\n"

  printf "\n${BLUE}check (git-project-link)${DARKYELLOW}\t\t Clones a project from the specified Git repository,\n\t\t\t\t\t switches to the 'develop' branch, checks formatting using clang-format and cppcheck,\n\t\t\t\t\t and opens the project in Visual Studio Code.\n\t\t\t\t\t Example: check https://github.com/username/project.git${END}\n"

  printf "\n${BLUE}push [commit]${DARKYELLOW}\t\t\t\t Checks formatting using clang-format in *.c, *.cc, *.h, *.cpp files,\n\t\t\t\t\t commits changes with the specified message (or default 'backup'),\n\t\t\t\t\t and pushes to the 'develop' branch or current branch if -d flag is used.\n\t\t\t\t\t Example: push 'Commit message', push, push -d 'Commit message', push -d${END}\n"

  printf "\n${BLUE}code [path]${DARKYELLOW}\t\t\t\t Opens a file or directory in Visual Studio Code.\n\t\t\t\t\t Example: code ., code path/to/file${END}\n"

  printf "\n${BLUE}clean${DARKYELLOW}\t\t\t\t\t Cleans various temporary files and caches to free up memory.\n\t\t\t\t\t Example: clean${END}\n"

  printf "\n${BLUE}sql (-flag)${DARKYELLOW}\t\t\t\t Manages SQL assignment folders:${END}\n"
  printf "\t\t${BLUE}-c${DARKYELLOW}\t\t Creates a specified number of folders with SQL assignments and a day-specified SQL file.\n\t\t\t\t Example: sql -c, 10, 5, y${END}\n"
  printf "\t\t${BLUE}-d${DARKYELLOW}\t\t Deletes all SQL assignment folders matching the pattern [ex**] in the current directory.\n\t\t\t\t Example: sql -d, y${END}\n"

  printf "\n${BLUE}roll${DARKYELLOW}\t\t\t\t\t Simulates a dice roll and displays the result.\n\t\t\t\t\t Example: roll${END}\n"

  printf "\n${BLUE}wttr${DARKYELLOW}\t\t\t\t\t Displays the weather in Novosibirsk using the wttr.in service.\n\t\t\t\t\t Example: wttr${END}\n"
  
}

function check {
  echo '[32mClone[0m'
  git clone $1
  cd $(echo $1 | awk -F / '{print $NF}' | sed -r 's/.git+//')
  git checkout develop
  code .

  echo '[32mCheck clang-format[0m'
  cd src
  cp ../materials/linters/.clang-format .
  clang-format -n $(find . -type f -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.cc")
  rm -rf .clang-format

  echo '[32mCpp check[0m'
  cppcheck --enable=all --suppress=missingIncludeSystem *.c *.h *.cpp *.cc
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


function roll {
roll=$((RANDOM % 6 + 1))

print_dice() {
    case $1 in
        1)
            echo "┌─────┐
│     │
│  *  │
│     │
└─────┘
"
            ;;
        2)
            echo "┌─────┐
│ *   │
│     │
│   * │
└─────┘
"
            ;;
        3)
            echo "┌─────┐
│ *   │
│  *  │
│   * │
└─────┘
"
            ;;
        4)
            echo "┌─────┐
│ * * │
│     │
│ * * │
└─────┘
"
            ;;
        5)
            echo "┌─────┐
│ * * │
│  *  │
│ * * │
└─────┘
"
            ;;
        6)
            echo "┌─────┐
│ * * │
│ * * │
│ * * │
└─────┘
"
            ;;
    esac
}
print_dice $roll
}

function wttr {
curl "https://wttr.in/Novosibirsk?lang=ru"
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
