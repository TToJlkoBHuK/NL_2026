# Задача 1.4. Конвейер "производитель-потребитель" для разбора журналов.
#
# Потоки-читатели разбирают каталог с файлами и построчно складывают строки
# в общую очередь. Потоки-обработчики достают строки из очереди, разбирают их
# и копят общую статистику. Очередь ограничена по размеру: если обработчики
# не успевают, читатели сами останавливаются на push и ждут - память не растёт.

# Общая статистика. Единственное место, где потоки пишут в одни и те же данные,
# поэтому каждое изменение идёт под мьютексом.
class Stats
  def initialize
    @mutex = Mutex.new
    @lines = 0
    @broken = 0
    @by_level = Hash.new(0)
    @messages = Hash.new(0)
  end

  def add(level, message)
    @mutex.synchronize do
      @lines += 1
      @by_level[level] += 1
      @messages[message] += 1
    end
  end

  def add_broken
    @mutex.synchronize { @broken += 1 }
  end

  def report(top_n)
    @mutex.synchronize do
      top = @messages.sort_by { |_, count| -count }.first(top_n)
      {
        lines: @lines,
        broken: @broken,
        by_level: @by_level.sort.to_h,
        top: top
      }
    end
  end
end

LINE_FORMAT = /\A(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) (INFO|WARN|ERROR) (.+)\z/

def run(dir, producer_count, consumer_count)
  files = Dir.glob(File.join(dir, "*.log")).sort
  if files.empty?
    puts "В каталоге #{dir} нет файлов .log"
    return
  end

  puts "Файлов: #{files.size}, читателей: #{producer_count}, обработчиков: #{consumer_count}"
  puts

  # очередь файлов: читатели разбирают её сами, без заранее заданного распределения
  file_queue = Queue.new
  files.each { |f| file_queue << f }

  # очередь строк с ограничением - тот самый ограничитель конвейера
  line_queue = SizedQueue.new(2000)
  stats = Stats.new
  started = Time.now

  producers = producer_count.times.map do |i|
    Thread.new do
      loop do
        file = begin
                 file_queue.pop(true)
               rescue ThreadError
                 nil
               end
        break if file.nil?

        puts "читатель #{i + 1} взял #{File.basename(file)}"
        # кодировку задаём явно, иначе она зависит от настроек системы
        File.foreach(file, encoding: "UTF-8") { |line| line_queue << line }
      end
    end
  end

  consumers = consumer_count.times.map do
    Thread.new do
      loop do
        line = line_queue.pop
        break if line == :done

        match = LINE_FORMAT.match(line.strip)
        if match
          stats.add(match[3], match[4])
        else
          stats.add_broken
        end
      end
    end
  end

  # ждём, пока прочитаны все файлы, и только потом кладём в очередь
  # по одной метке конца на каждого обработчика
  producers.each(&:join)
  consumer_count.times { line_queue << :done }
  consumers.each(&:join)

  spent = Time.now - started
  result = stats.report(5)

  puts
  puts "Разобрано строк:   #{result[:lines]}"
  puts "Битых строк:       #{result[:broken]}"
  puts
  puts "По уровням:"
  result[:by_level].each { |level, count| puts format("  %-6s %d", level, count) }
  puts
  puts "Пять самых частых сообщений:"
  result[:top].each_with_index do |(message, count), i|
    puts format("  %d. %-28s %d", i + 1, message, count)
  end
  puts
  puts format("Время работы: %.2f с", spent)
end

dir = ARGV[0] || "logs"
producer_count = (ARGV[1] || 2).to_i
consumer_count = (ARGV[2] || 4).to_i

run(dir, producer_count, consumer_count)
