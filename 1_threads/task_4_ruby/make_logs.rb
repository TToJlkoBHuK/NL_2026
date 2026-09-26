# Создаёт тестовые файлы журналов для pipeline.rb.
# Запуск: ruby make_logs.rb [каталог] [файлов] [строк в файле]

dir = ARGV[0] || "logs"
files = (ARGV[1] || 4).to_i
lines = (ARGV[2] || 15000).to_i

MESSAGES = [
  "user login ok",
  "user logout",
  "cache hit",
  "cache miss",
  "request handled",
  "slow query detected",
  "connection reset by peer",
  "disk usage high",
  "config reloaded",
  "background job finished",
  "database timeout",
  "invalid token"
]

Dir.mkdir(dir) unless Dir.exist?(dir)

files.times do |f|
  random = Random.new(1000 + f)
  File.open(File.join(dir, format("app_%d.log", f + 1)), "w:UTF-8") do |out|
    time = Time.new(2026, 3, 1 + f, 0, 0, 0)
    lines.times do
      time += random.rand(1..4)

      # одна строка из ста намеренно битая - программа должна их пережить
      if random.rand(100).zero?
        out.puts "### повреждённая строка ###"
        next
      end

      roll = random.rand(100)
      level = if roll < 80
                "INFO"
              elsif roll < 95
                "WARN"
              else
                "ERROR"
              end

      # перекос к началу списка, чтобы частоты сообщений заметно отличались
      message = MESSAGES[(MESSAGES.size * random.rand**2).to_i]
      out.puts format("%s %s %s", time.strftime("%Y-%m-%d %H:%M:%S"), level, message)
    end
  end
end

puts "Готово: #{files} файлов по #{lines} строк в каталоге #{dir}"
