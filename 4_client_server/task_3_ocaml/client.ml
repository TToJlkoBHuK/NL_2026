let () =
  let host = if Array.length Sys.argv > 1 then Sys.argv.(1) else "127.0.0.1" in
  let port = if Array.length Sys.argv > 2 then int_of_string Sys.argv.(2) else 9000 in

  let address =
    try Unix.ADDR_INET (Unix.inet_addr_of_string host, port)
    with _ ->
      let entry = Unix.gethostbyname host in
      Unix.ADDR_INET (entry.Unix.h_addr_list.(0), port)
  in

  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.connect sock address;
  Printf.printf "подключено к %s:%d\n%!" host port;

  let inc = Unix.in_channel_of_descr sock in
  let outc = Unix.out_channel_of_descr sock in

  let rec loop () =
    match input_line inc with
    | line ->
      print_string line;
      print_newline ();
      if String.length line >= 2 && String.sub line 0 2 = "До" then ()
      else begin
        print_string "> ";
        flush stdout;
        match input_line stdin with
        | answer ->
          output_string outc (answer ^ "\n");
          flush outc;
          loop ()
        | exception End_of_file -> ()
      end
    | exception End_of_file -> print_endline "сервер закрыл соединение"
  in

  loop ();
  (try Unix.close sock with _ -> ())
