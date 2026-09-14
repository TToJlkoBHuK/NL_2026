#!/usr/bin/env bash
# Создаёт тестовые текстовые файлы для Main.kt.
# Запуск: bash make_data.sh [каталог] [файлов] [слов в файле]

dir=${1:-files}
count=${2:-6}
words=${3:-60000}

mkdir -p "$dir"

for i in $(seq 1 "$count"); do
  awk -v seed="$i" -v n="$words" 'BEGIN {
    srand(seed);
    m = split("время работа поток данные файл строка слово память процесс задача \
система сервер клиент запрос ответ число массив список объект функция \
цикл условие ошибка результат значение ключ таблица индекс модуль пакет", v, " ");
    line = "";
    for (k = 1; k <= n; k++) {
      # степень у rand() перекашивает выбор к началу списка,
      # чтобы частоты слов отличались и топ-10 имел смысл
      idx = int(m * (rand() ^ 3)) + 1;
      line = line v[idx];
      if (k % 12 == 0) { print line; line = ""; } else { line = line " "; }
    }
    if (line != "") print line;
  }' > "$dir/text_$i.txt"
done

echo "Готово: $count файлов по $words слов в каталоге $dir"
ls -lh "$dir"
