import scala.collection.mutable.ArrayBuffer
import scala.collection.mutable.HashMap
import scala.io.Source

object Dijkstra {

  // двоичная куча на массивах, с ленивым удалением устаревших пар
  class MinHeap(capacity: Int) {
    private val dist = new Array[Long](capacity)
    private val node = new Array[Int](capacity)
    private var size = 0

    def isEmpty: Boolean = size == 0

    def push(d: Long, v: Int): Unit = {
      dist(size) = d
      node(size) = v
      var i = size
      size += 1
      var up = true
      while (up && i > 0) {
        val parent = (i - 1) / 2
        if (dist(parent) <= dist(i)) up = false
        else {
          swap(parent, i)
          i = parent
        }
      }
    }

    def pop(): (Long, Int) = {
      val topDist = dist(0)
      val topNode = node(0)
      size -= 1
      dist(0) = dist(size)
      node(0) = node(size)
      var i = 0
      var down = true
      while (down) {
        val left = 2 * i + 1
        val right = 2 * i + 2
        var small = i
        if (left < size && dist(left) < dist(small)) small = left
        if (right < size && dist(right) < dist(small)) small = right
        if (small == i) down = false
        else {
          swap(i, small)
          i = small
        }
      }
      (topDist, topNode)
    }

    private def swap(a: Int, b: Int): Unit = {
      val d = dist(a); dist(a) = dist(b); dist(b) = d
      val n = node(a); node(a) = node(b); node(b) = n
    }
  }

  class Graph {
    val index = new HashMap[String, Int]()
    val names = new ArrayBuffer[String]()
    val edges = new ArrayBuffer[ArrayBuffer[(Int, Long)]]()
    var edgeCount = 0

    def id(name: String): Int = {
      index.get(name) match {
        case Some(i) => i
        case None =>
          val i = names.length
          index.put(name, i)
          names += name
          edges += new ArrayBuffer[(Int, Long)]()
          i
      }
    }

    def addEdge(from: String, to: String, weight: Long): Unit = {
      val a = id(from)
      val b = id(to)
      edges(a) += ((b, weight))
      edgeCount += 1
    }
  }

  def load(path: String): Graph = {
    val graph = new Graph
    val source = Source.fromFile(path)
    try {
      for (raw <- source.getLines()) {
        val line = raw.trim
        if (line.nonEmpty && !line.startsWith("#")) {
          val parts = line.split("\\s+")
          if (parts.length != 3) throw new RuntimeException("плохая строка: " + line)
          graph.addEdge(parts(0), parts(1), parts(2).toLong)
        }
      }
    } finally {
      source.close()
    }
    graph
  }

  def main(args: Array[String]): Unit = {
    if (args.length < 3) {
      println("Использование: scala Dijkstra <файл графа> <откуда> <куда>")
      return
    }

    val graph = load(args(0))
    if (!graph.index.contains(args(1)) || !graph.index.contains(args(2))) {
      println("Такой вершины в графе нет")
      return
    }

    val start = graph.index(args(1))
    val finish = graph.index(args(2))
    val count = graph.names.length

    val best = Array.fill[Long](count)(Long.MaxValue)
    val prev = Array.fill[Int](count)(-1)
    val done = Array.fill[Boolean](count)(false)

    val heap = new MinHeap(graph.edgeCount + count + 1)
    best(start) = 0L
    heap.push(0L, start)

    while (!heap.isEmpty) {
      val (d, v) = heap.pop()
      if (!done(v)) {
        done(v) = true
        for ((to, weight) <- graph.edges(v)) {
          if (d + weight < best(to)) {
            best(to) = d + weight
            prev(to) = v
            heap.push(best(to), to)
          }
        }
      }
    }

    println("Вершин: " + count + ", рёбер: " + graph.edgeCount)
    println()

    if (best(finish) == Long.MaxValue) {
      println("Пути из " + args(1) + " в " + args(2) + " не существует")
    } else {
      val path = new ArrayBuffer[String]()
      var at = finish
      while (at != -1) {
        path += graph.names(at)
        at = prev(at)
      }
      println("Кратчайший путь: " + path.reverse.mkString(" -> "))
      println("Длина пути: " + best(finish))
    }

    println()
    println("Расстояния от " + args(1) + ":")
    for (i <- 0 until count) {
      val value = if (best(i) == Long.MaxValue) "недостижима" else best(i).toString
      println("  %-4s %s".format(graph.names(i), value))
    }
  }
}
