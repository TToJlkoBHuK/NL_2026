// Задача 1.2. Сегментное решето Эратосфена на пуле потоков.
//
// Отрезок от 1 до N режется на блоки одинаковой длины. Блоки не закрепляются
// за потоками заранее: каждый поток в цикле берёт номер очередного необработанного
// блока из общего счётчика под мьютексом, просеивает его и отправляет результат
// главному потоку через канал. Так медленные блоки не задерживают остальные потоки.

use std::env;
use std::sync::mpsc;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Instant;

// Обычное решето Эратосфена. Нужно, чтобы получить базовые простые числа
// до корня из N: именно ими потом просеивается каждый блок.
fn simple_sieve(limit: u64) -> Vec<u64> {
    if limit < 2 {
        return Vec::new();
    }
    let n = limit as usize;
    let mut is_prime = vec![true; n + 1];
    is_prime[0] = false;
    is_prime[1] = false;
    let mut p: usize = 2;
    while p * p <= n {
        if is_prime[p] {
            let mut m = p * p;
            while m <= n {
                is_prime[m] = false;
                m += p;
            }
        }
        p += 1;
    }
    let mut result = Vec::new();
    for i in 2..=n {
        if is_prime[i] {
            result.push(i as u64);
        }
    }
    result
}

// Просеивает один блок [lo, hi). Память под блок выделяется своя,
// поэтому потоки не мешают друг другу и блокировки здесь не нужны.
fn sieve_block(lo: u64, hi: u64, base: &[u64]) -> Vec<u64> {
    if hi <= lo {
        return Vec::new();
    }
    let size = (hi - lo) as usize;
    let mut is_prime = vec![true; size];

    for &p in base {
        if p * p >= hi {
            break;
        }
        // первое кратное p внутри блока
        let mut start = if lo % p == 0 { lo } else { lo + (p - lo % p) };
        // числа меньше p*p уже вычеркнуты меньшими простыми
        if start < p * p {
            start = p * p;
        }
        let mut m = start;
        while m < hi {
            is_prime[(m - lo) as usize] = false;
            m += p;
        }
    }

    let mut result = Vec::new();
    for i in 0..size {
        let value = lo + i as u64;
        if value >= 2 && is_prime[i] {
            result.push(value);
        }
    }
    result
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let n: u64 = if args.len() > 1 {
        args[1].parse().expect("N должно быть числом")
    } else {
        10_000_000
    };
    let threads: usize = if args.len() > 2 {
        args[2].parse().expect("число потоков должно быть числом")
    } else {
        4
    };

    let block_size: u64 = 100_000;
    let block_count = ((n + 1) as f64 / block_size as f64).ceil() as usize;

    // базовые простые до корня из N
    let root = (n as f64).sqrt() as u64 + 1;
    let base = Arc::new(simple_sieve(root));

    println!("N = {}, потоков: {}, блоков: {} по {} чисел",
             n, threads, block_count, block_size);
    println!("базовых простых до {}: {}", root, base.len());
    println!();

    // общий счётчик выданных блоков - единственное, что потоки делят между собой
    let next_block = Arc::new(Mutex::new(0usize));
    let (tx, rx) = mpsc::channel::<(usize, usize, Vec<u64>)>();

    let start = Instant::now();
    let mut handles = Vec::new();

    for _ in 0..threads {
        let next_block = Arc::clone(&next_block);
        let base = Arc::clone(&base);
        let tx = tx.clone();

        handles.push(thread::spawn(move || {
            loop {
                // берём номер следующего блока
                let index = {
                    let mut guard = next_block.lock().unwrap();
                    let i = *guard;
                    *guard += 1;
                    i
                };
                if index >= block_count {
                    break;
                }

                let lo = index as u64 * block_size;
                let hi = std::cmp::min(lo + block_size, n + 1);
                let primes = sieve_block(lo, hi, &base);

                // наружу отдаём количество и хвост блока, а не весь список,
                // чтобы не гонять по каналу миллионы чисел
                let from = if primes.len() > 10 { primes.len() - 10 } else { 0 };
                let tail = primes[from..].to_vec();
                tx.send((index, primes.len(), tail)).unwrap();
            }
        }));
    }

    // свой конец канала закрываем, иначе цикл по rx никогда не завершится
    drop(tx);

    let mut results: Vec<Option<(usize, Vec<u64>)>> = vec![None; block_count];
    for (index, count, tail) in rx {
        results[index] = Some((count, tail));
    }
    for h in handles {
        h.join().unwrap();
    }
    let parallel_time = start.elapsed();

    let mut total = 0usize;
    for r in &results {
        if let Some((count, _)) = r {
            total += count;
        }
    }

    // последние десять простых собираем, идя по блокам с конца
    let mut last: Vec<u64> = Vec::new();
    for r in results.iter().rev() {
        if let Some((_, tail)) = r {
            let mut copy = tail.clone();
            copy.extend(last.iter());
            last = copy;
            if last.len() >= 10 {
                break;
            }
        }
    }
    if last.len() > 10 {
        let from = last.len() - 10;
        last = last[from..].to_vec();
    }

    // контрольный однопоточный расчёт
    let start = Instant::now();
    let check = simple_sieve(n);
    let single_time = start.elapsed();

    println!("простых чисел найдено: {}", total);
    println!("последние десять:      {:?}", last);
    println!();
    println!("{} потока(ов): {:?}", threads, parallel_time);
    println!("один поток:   {:?}", single_time);
    println!("ускорение:    {:.2} раза",
             single_time.as_secs_f64() / parallel_time.as_secs_f64());
    println!();
    println!("однопоточная проверка дала {} простых, совпадает: {}",
             check.len(), check.len() == total);
}
