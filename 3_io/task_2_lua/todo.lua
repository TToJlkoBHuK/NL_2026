local path = arg[1] or "tasks.txt"
local tasks = {}

local function load()
    tasks = {}
    local file = io.open(path, "r")
    if not file then return end
    for line in file:lines() do
        local done, date, text = line:match("^(%d)|([^|]*)|(.*)$")
        if done then
            tasks[#tasks + 1] = { done = done == "1", date = date, text = text }
        end
    end
    file:close()
end

local function save()
    local file = io.open(path, "w")
    if not file then
        print("не удаётся записать " .. path)
        return
    end
    for _, task in ipairs(tasks) do
        file:write(task.done and "1" or "0", "|", task.date, "|", task.text, "\n")
    end
    file:close()
end

local function list(filter)
    if #tasks == 0 then
        print("список пуст")
        return
    end
    local shown = 0
    for i, task in ipairs(tasks) do
        if not filter or task.text:lower():find(filter:lower(), 1, true) then
            print(string.format("%3d  [%s]  %s  %s", i, task.done and "x" or " ", task.date, task.text))
            shown = shown + 1
        end
    end
    if shown == 0 then print("ничего не найдено") end
end

local function pick(rest)
    local n = tonumber(rest)
    if not n or not tasks[n] then
        print("нужен номер задачи из списка")
        return nil
    end
    return n
end

local commands = {}

commands.add = function(rest)
    if rest == "" then
        print("после add нужен текст задачи")
        return
    end
    tasks[#tasks + 1] = { done = false, date = os.date("%Y-%m-%d"), text = rest }
    save()
    print("добавлено под номером " .. #tasks)
end

commands.list = function() list(nil) end

commands.find = function(rest)
    if rest == "" then
        print("после find нужна подстрока")
        return
    end
    list(rest)
end

commands.done = function(rest)
    local n = pick(rest)
    if not n then return end
    tasks[n].done = true
    save()
    print("задача " .. n .. " отмечена выполненной")
end

commands.del = function(rest)
    local n = pick(rest)
    if not n then return end
    local removed = table.remove(tasks, n)
    save()
    print("удалено: " .. removed.text)
end

commands.help = function()
    print("add <текст>   добавить задачу")
    print("list          показать все")
    print("find <текст>  поиск по подстроке")
    print("done <номер>  отметить выполненной")
    print("del <номер>   удалить")
    print("exit          выход")
end

load()
print("Файл списка: " .. path .. ", задач: " .. #tasks)
print("Команда help покажет список команд.")

while true do
    io.write("> ")
    io.flush()
    local line = io.read("l")
    if not line then break end

    local name, rest = line:match("^%s*(%S*)%s*(.-)%s*$")
    if name == "exit" or name == "quit" then
        break
    elseif name == "" then
        -- пустая строка, ничего не делаем
    elseif commands[name] then
        commands[name](rest)
    else
        print("неизвестная команда: " .. name .. " (help - список команд)")
    end
end

print("сохранено в " .. path)
