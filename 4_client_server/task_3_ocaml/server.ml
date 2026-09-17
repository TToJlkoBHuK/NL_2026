let low = ref 1
let high = ref 100

let play fd addr =
  let inc = Unix.in_channel_of_descr fd in
  let outc = Unix.out_channel_of_descr fd in
  let who =
    match addr with
    | Unix.ADDR_INET (ip, port) -> Printf.sprintf "%s:%d" (Unix.string_of_inet_addr ip) port
    | _ -> "?"
  in
  let say text = output_string outc text; flush outc in

  let rec game round =
    let secret = !low + Random.int (!high - !low + 1) in
    Printf.printf "%s: партия %d, загадано %d\n%!" who round secret;
    say (Printf.sprintf "Загадано число от %d до %d. Ваш вариант?\n" !low !high);

    let rec guess tries =
      match input_line inc with
      | line ->
        let text = String.trim line in
        if text = "" then guess tries
        else if text = "quit" then say "До встречи.\n"
        else begin
          match int_of_string_opt text with
          | None ->
            say "Это не число, попробуйте ещё раз.\n";
            guess tries
          | Some value ->
            let tries = tries + 1 in
            if value < secret then (say "Больше.\n"; guess tries)
            else if value > secret then (say "Меньше.\n"; guess tries)
            else begin
              say (Printf.sprintf "Угадали! Попыток: %d. Ещё партию? (да/нет)\n" tries);
              Printf.printf "%s: угадал за %d попыток\n%!" who tries;
              match input_line inc with
              | answer when String.trim answer = "да" -> game (round + 1)
              | _ -> say "До встречи.\n"
              | exception End_of_file -> ()
            end
        end
      | exception End_of_file -> ()
    in
    guess 0
  in

  (try game 1 with Sys_error _ -> ());
  Printf.printf "%s: отключился\n%!" who;
  (try close_out outc with _ -> ())

let () =
  let port = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 9000 in
  if Array.length Sys.argv > 3 then begin
    low := int_of_string Sys.argv.(2);
    high := int_of_string Sys.argv.(3)
  end;

  Random.self_init ();
  (* чтобы завершённые дочерние процессы не оставались зомби *)
  ignore (Sys.signal Sys.sigchld Sys.Signal_ignore);

  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_any, port));
  Unix.listen sock 8;
  Printf.printf "сервер слушает порт %d, диапазон %d..%d\n%!" port !low !high;

  while true do
    let (client, addr) = Unix.accept sock in
    match Unix.fork () with
    | 0 ->
      Unix.close sock;
      play client addr;
      (try Unix.close client with _ -> ());
      exit 0
    | _ -> Unix.close client
  done
