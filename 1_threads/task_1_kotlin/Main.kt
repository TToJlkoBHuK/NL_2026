// Задача 1.1. Параллельный подсчёт частоты слов в наборе текстовых файлов.
//
// Файлы раздаются потокам, каждый поток считает слова только в своих файлах
// и копит их в собственном словаре. Общий словарь трогается один раз в конце
// работы потока, под блокировкой: так потоки почти не ждут друг друга.

import java.io.File

// Считает слова в одном файле. Словом считается непрерывная цепочка букв и цифр,
// регистр не учитывается. Разбор идёт посимвольно, без регулярных выражений.
fun countWordsInFile(file: File): HashMap<String, Long> {
    val counts = HashMap<String, Long>()
    val word = StringBuilder()

    file.forEachLine { line ->
        for (ch in line) {
            if (ch.isLetterOrDigit()) {
                word.append(ch.lowercaseChar())
            } else if (word.isNotEmpty()) {
                val w = word.toString()
                counts[w] = (counts[w] ?: 0L) + 1L
                word.setLength(0)
            }
        }
        // слово могло закончиться вместе со строкой
        if (word.isNotEmpty()) {
            val w = word.toString()
            counts[w] = (counts[w] ?: 0L) + 1L
            word.setLength(0)
        }
    }
    return counts
}

// Досыпает содержимое одного словаря в другой.
fun mergeInto(target: HashMap<String, Long>, source: HashMap<String, Long>) {
    for (entry in source) {
        target[entry.key] = (target[entry.key] ?: 0L) + entry.value
    }
}

// Однопоточный вариант, нужен для сравнения времени и для проверки результата.
fun countSingleThread(files: List<File>): HashMap<String, Long> {
    val total = HashMap<String, Long>()
    for (f in files) {
        mergeInto(total, countWordsInFile(f))
    }
    return total
}

fun countManyThreads(files: List<File>, threadCount: Int): HashMap<String, Long> {
    val total = HashMap<String, Long>()
    val lock = Any()
    val threads = ArrayList<Thread>()

    for (i in 0 until threadCount) {
        // файлы раздаются "через один", чтобы крупные и мелкие
        // разошлись по потокам более или менее поровну
        val myFiles = ArrayList<File>()
        var j = i
        while (j < files.size) {
            myFiles.add(files[j])
            j += threadCount
        }

        threads.add(Thread {
            val local = HashMap<String, Long>()
            for (f in myFiles) {
                mergeInto(local, countWordsInFile(f))
            }
            // единственное место, где потоки пересекаются
            synchronized(lock) {
                mergeInto(total, local)
            }
        })
    }

    for (t in threads) t.start()
    for (t in threads) t.join()
    return total
}

fun printTop(counts: HashMap<String, Long>, n: Int) {
    val top = counts.entries.sortedByDescending { it.value }.take(n)
    var place = 1
    for (e in top) {
        println(String.format("%2d. %-16s %d", place, e.key, e.value))
        place++
    }
}

fun main(args: Array<String>) {
    if (args.size < 2) {
        println("Использование: java -jar app.jar <каталог> <число потоков>")
        return
    }

    val dir = File(args[0])
    val threadCount = args[1].toInt()

    val files = ArrayList<File>()
    val all = dir.listFiles()
    if (all != null) {
        for (f in all) {
            if (f.isFile && f.name.endsWith(".txt")) files.add(f)
        }
    }
    files.sortBy { it.name }

    if (files.isEmpty()) {
        println("В каталоге ${dir.path} нет файлов .txt")
        return
    }

    println("Файлов: ${files.size}, потоков: $threadCount")
    println()

    val startOne = System.currentTimeMillis()
    val one = countSingleThread(files)
    val timeOne = System.currentTimeMillis() - startOne

    val startMany = System.currentTimeMillis()
    val many = countManyThreads(files, threadCount)
    val timeMany = System.currentTimeMillis() - startMany

    var totalWords = 0L
    for (c in many.values) totalWords += c

    println("Всего слов:      $totalWords")
    println("Уникальных слов: ${many.size}")
    println()
    println("Топ-10 слов:")
    printTop(many, 10)
    println()
    println("Один поток:      $timeOne мс")
    println("Потоков $threadCount:      $timeMany мс")
    if (timeMany > 0) {
        println(String.format("Ускорение:       %.2f раза", timeOne.toDouble() / timeMany.toDouble()))
    }
    println("Оба способа дали одинаковый результат: " + (one == many))
}
