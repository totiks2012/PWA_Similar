23_06_2025 
Update -- Обновление
В этом обновлении улучшил отзывчивость нажатия кнопок, до этого они срабптывали нв второе нажатие, тепь достаточно одного 
нажатия кнопки.

# PWA_Similar
this is a bookmark manager written in tcl/tk, it can also create a desktop file with an icon for the bookmark if needed
# Менеджер Закладок PWA Similar Manager

## PWA Similar Manager - 

это мощный менеджер закладок с графическим интерфейсом на Tcl/Tk, предназначенный для организации и управления веб-закладками. Хотя приложение также может создавать PWA-подобные приложения, его основная функция - управление закладками.

1. 

## Основные функции

- Организация закладок

- Группировка по категориям : Закладки можно организовывать в отдельные вкладки/группы

- Нечеткий поиск : Быстрый поиск закладок внутри текущей группы

- Перемещение элементов : Возможность изменять порядок закладок

- Преимущества перед браузерными закладками

- Гибкая организация :

- Создание произвольных групп (вкладок)

- Независимость от конкретного браузера

## Дополнительные возможности :

- Импорт/Экспорт всех данных

- Визуальное представление

- Безопасность :
Резервное копирование через систему архивов

- Хранение вне браузера

## Особенности работы с закладками

- Добавление : Через кнопку "+" 

- Удаление : Кнопка "-"

- Поиск : Ctrl+F или поле поиска

- Организация : Перемещение стрелками вверх/вниз

- Группировка : Создание новых вкладок через "Tab+"

## Импорт/Экспорт

Преимущества собственной системы импорта/экспорта:

Независимость от браузера

Полное резервное копирование :

Все группы закладок

Порядок элементов

## Настройки

Простота использования :

Одно нажатие для экспорта

Автоматическое восстановление при импорте

### Зависимости
Для работы приложения необходимы:

Основные зависимости :

Tcl/Tk 8.6 или выше


Утилиты Linux:
notify-send
xdg-open
tar
file
wget

Скрипты :
download_icon.sh (должен находиться в той же директории)

Директории :
~/.local/share/applications для .desktop файлов (при использовании функции PWA)

Локальная директория icons/ для хранения иконок

Использование download_icon.sh
Скрипт download_icon.sh используется для загрузки иконок сайтов при добавлении закладок.
 Он проверяет несколько стандартных мест расположения favicon:


```
favicon_urls=(
    "http://$domain/favicon.ico"
    "http://$domain/favicon.png"
    "http://$domain/favicon.svg"
    "http://$domain/favicon32.png"
    "http://$domain/apple-touch-icon.png"
)
```

Принцип работы:
Извлекает домен из URL
Проверяет стандартные пути favicon
Скачивает первую доступную иконку
Сохраняет её в локальную директорию

Конфигурация
Приложение использует файл config.conf для настройки внешнего вида:

font_color = #RRGGBB      # Цвет шрифта

bg_color = #RRGGBB        # Цвет фона

list_font_size = N        # Размер шрифта списка

control_font_size = N     # Размер шрифта элементов управления

line_spacing = N          # Интервал между строками

## Почему это лучше браузерных закладок?


Работает независимо от браузера (вернее достаточно поменять браузер по умолчанию и ссылки будут открыватся в нём)

Можно использовать с любым браузером,
Каждый браузер рендерит списки закладок по своему ,приходится привыкать заново , тут скопировали каталог со скриптом и плейлистами закладок, и мы уже обладаем доступом к закладкам к которым привыкли

## Гибкость :

- Неограниченное количество групп

- Произвольный порядок элементов

- Поиск внутри групп

## Безопасность :

- Регулярное резервное копирование

- Хранение в локальных файлах

Удобство :

Графический интерфейс

Горячие клавиши

Всплывающие подсказки

Уведомления системы

## Установка
Скачайте архив со скриптом

Разархивируйте в */home/user/.local/bin/pwa_similar/*

где user имя вашего ползователя

также скоректируйте имя вашего пользователя в скрипте

Launch_Pwa-Similar.sh


Установите зависимости если их нет

```
sudo apt-get install tcl tk libnotify-bin xdg-utils wget

```
Сделайте исполняемыми основной скрипт и скрипт загрузки иконок:
bash


перейдите в директорию со скриптом
```
cd /home/user/.local/bin/pwa_similar/

```

сделайте исполнемыми скрипты 
```
chmod +x ./pwa_similar_16-copilot-latest.tcl ./download_icon.sh ./Launch_Pwa-Similar.sh

```

Запустите приложение командой

```
./Launch_Pwa-Similar.sh

```
*Примечания*

При первом запуске приложение создаст необходимые директории и файлы
Для корректной работы требуется активное интернет-соединение (для загрузки иконок)
Рекомендуется периодически делать backup через функцию экспорта

Лицензия
GPL v 3.0 License

Поддержка
Если вы нашли ошибку или хотите предложить новую функцию, пожалуйста, создайте issue в репозитории.

Автор
[totiks2012]

при поддержке Copilot (Claude Sonet 3.7)






