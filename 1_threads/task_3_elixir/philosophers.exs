# Задача 1.3. Обедающие философы.
#
# Каждая вилка и каждый философ - отдельный процесс. Общей памяти нет,
# всё взаимодействие идёт сообщениями. Состояние вилки хранится не в переменной,
# а в том, в какой функции сейчас находится её процесс: free или busy.

defmodule Fork do
  # Вилка свободна: ждём запрос, отвечаем владельцу и уходим в busy.
  defp free(number) do
    receive do
      {:take, who} ->
        send(who, {:taken, number})
        busy(number)
    end
  end

  # Вилка занята: здесь мы принимаем только :put. Запросы {:take, ...}
  # никуда не деваются, они ждут своей очереди в почтовом ящике процесса
  # и будут разобраны, когда вилку вернут. Очередь получается бесплатно.
  defp busy(number) do
    receive do
      :put -> free(number)
    end
  end

  def start(number) do
    {spawn(fn -> free(number) end), number}
  end
end

defmodule Philosopher do
  def start(name, first, second) do
    spawn(fn -> loop(name, first, second, 0) end)
  end

  defp loop(name, first, second, meals) do
    log("#{name} думает")
    Process.sleep(60 + :rand.uniform(140))

    case check_stop() do
      {:stop, main} ->
        # обед закончен, отчитываемся главному процессу
        send(main, {:report, name, meals})

      :run ->
        log("#{name} проголодался")
        take(first, name)
        take(second, name)

        log("#{name} ЕСТ, приём пищи номер #{meals + 1}")
        Process.sleep(40 + :rand.uniform(90))

        put(first, name)
        put(second, name)
        loop(name, first, second, meals + 1)
    end
  end

  defp take({pid, number}, name) do
    send(pid, {:take, self()})
    # ждём подтверждения именно от этой вилки
    receive do
      {:taken, ^number} -> log("#{name} взял вилку #{number}")
    end
  end

  defp put({pid, number}, name) do
    send(pid, :put)
    log("#{name} положил вилку #{number}")
  end

  # Неблокирующая проверка почтового ящика: если команды на выход нет,
  # after 0 срабатывает сразу и философ продолжает обедать.
  defp check_stop do
    receive do
      {:stop, main} -> {:stop, main}
    after
      0 -> :run
    end
  end

  defp log(text), do: IO.puts(text)
end

defmodule Dinner do
  def run(count, seconds) do
    IO.puts("Философов: #{count}, вилок: #{count}, время обеда: #{seconds} с")
    IO.puts("Философ #{count} берёт вилки в обратном порядке - это и спасает от взаимной блокировки")
    IO.puts("")

    forks = for number <- 1..count, do: Fork.start(number)

    philosophers =
      for i <- 1..count do
        left = Enum.at(forks, i - 1)
        right = Enum.at(forks, rem(i, count))

        # Все берут сначала левую вилку, последний - сначала правую.
        # Если бы все брали в одном порядке, каждый мог бы взять по одной
        # вилке и замереть навсегда, ожидая вторую.
        {first, second} = if i == count, do: {right, left}, else: {left, right}

        Philosopher.start("Философ #{i}", first, second)
      end

    Process.sleep(seconds * 1000)

    IO.puts("")
    IO.puts("--- обед окончен, собираем статистику ---")
    Enum.each(philosophers, fn p -> send(p, {:stop, self()}) end)

    reports = collect(length(philosophers), [])

    IO.puts("")
    IO.puts("Сколько раз поел каждый:")

    total =
      Enum.reduce(Enum.sort(reports), 0, fn {name, meals}, acc ->
        IO.puts("  #{name}: #{meals}")
        acc + meals
      end)

    IO.puts("  всего приёмов пищи: #{total}")
  end

  defp collect(0, acc), do: acc

  defp collect(n, acc) do
    receive do
      {:report, name, meals} -> collect(n - 1, [{name, meals} | acc])
    after
      5000 ->
        IO.puts("  (часть философов не успела отчитаться)")
        acc
    end
  end
end

args = System.argv()
count = if length(args) > 0, do: String.to_integer(Enum.at(args, 0)), else: 5
seconds = if length(args) > 1, do: String.to_integer(Enum.at(args, 1)), else: 10

Dinner.run(count, seconds)
