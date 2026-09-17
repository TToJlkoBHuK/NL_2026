(require '[clojure.string :as str])

(def counters (atom {:headers 0 :lists 0 :links 0 :code 0 :quotes 0}))

(defn escape-html [s]
  (-> s
      (str/replace "&" "&amp;")
      (str/replace "<" "&lt;")
      (str/replace ">" "&gt;")))

(defn inline-format [s]
  (let [text (escape-html s)
        links (count (re-seq #"\[[^\]]+\]\([^)]+\)" text))]
    (swap! counters update :links + links)
    (-> text
        (str/replace #"`([^`]+)`" "<code>$1</code>")
        (str/replace #"\[([^\]]+)\]\(([^)]+)\)" "<a href=\"$2\">$1</a>")
        (str/replace #"\*\*([^*]+)\*\*" "<strong>$1</strong>")
        (str/replace #"\*([^*]+)\*" "<em>$1</em>"))))

(defn close-block [out state]
  (case state
    :ul (.append out "</ul>\n")
    :ol (.append out "</ol>\n")
    :quote (.append out "</blockquote>\n")
    :p (.append out "</p>\n")
    nil))

(defn convert [lines]
  (let [out (StringBuilder.)]
    (loop [remaining lines
           state :none]
      (if (empty? remaining)
        (do (close-block out state) (.toString out))
        (let [line (first remaining)
              tail (rest remaining)]
          (cond
            (re-find #"^\s*```" line)
            (if (= state :code)
              (do (.append out "</code></pre>\n") (recur tail :none))
              (do (close-block out state)
                  (swap! counters update :code inc)
                  (.append out "<pre><code>")
                  (recur tail :code)))

            (= state :code)
            (do (.append out (escape-html line)) (.append out "\n") (recur tail :code))

            (str/blank? line)
            (do (close-block out state) (recur tail :none))

            (re-find #"^#{1,6}\s+" line)
            (let [level (count (take-while #(= \# %) line))
                  text (str/trim (subs line level))]
              (close-block out state)
              (swap! counters update :headers inc)
              (.append out (format "<h%d>%s</h%d>\n" level (inline-format text) level))
              (recur tail :none))

            (re-find #"^\s*(-{3,}|\*{3,})\s*$" line)
            (do (close-block out state) (.append out "<hr>\n") (recur tail :none))

            (re-find #"^\s*[-*+]\s+" line)
            (do (when (not= state :ul) (close-block out state) (.append out "<ul>\n"))
                (swap! counters update :lists inc)
                (.append out (format "  <li>%s</li>\n" (inline-format (str/replace line #"^\s*[-*+]\s+" ""))))
                (recur tail :ul))

            (re-find #"^\s*\d+\.\s+" line)
            (do (when (not= state :ol) (close-block out state) (.append out "<ol>\n"))
                (swap! counters update :lists inc)
                (.append out (format "  <li>%s</li>\n" (inline-format (str/replace line #"^\s*\d+\.\s+" ""))))
                (recur tail :ol))

            (re-find #"^>\s?" line)
            (do (when (not= state :quote) (close-block out state) (.append out "<blockquote>\n"))
                (swap! counters update :quotes inc)
                (.append out (format "  <p>%s</p>\n" (inline-format (str/replace line #"^>\s?" ""))))
                (recur tail :quote))

            :else
            (if (= state :p)
              (do (.append out (str " " (inline-format line))) (recur tail :p))
              (do (close-block out state)
                  (.append out (str "<p>" (inline-format line)))
                  (recur tail :p)))))))))

(def page-head
  (str "<!doctype html>\n<html lang=\"ru\">\n<head>\n<meta charset=\"utf-8\">\n"
       "<title>%s</title>\n<style>\n"
       "body { font-family: Georgia, serif; max-width: 42em; margin: 2em auto; padding: 0 1em; line-height: 1.5; }\n"
       "pre { background: #f4f4f4; padding: .8em; overflow-x: auto; }\n"
       "code { background: #f4f4f4; padding: .1em .3em; }\n"
       "pre code { background: none; padding: 0; }\n"
       "blockquote { border-left: 3px solid #ccc; margin-left: 0; padding-left: 1em; color: #555; }\n"
       "</style>\n</head>\n<body>\n"))

(let [argv *command-line-args*]
  (if (< (count argv) 2)
    (println "Использование: clojure -M md2html.clj <вход.md> <выход.html>")
    (let [source (first argv)
          target (second argv)
          lines (str/split-lines (slurp source))
          title (or (some->> lines (filter #(re-find #"^#\s+" %)) first (re-find #"^#\s+(.*)$") second)
                    source)
          body (convert lines)]
      (spit target (str (format page-head title) body "</body>\n</html>\n"))
      (let [c @counters]
        (println (format "Заголовков: %d, пунктов списков: %d, ссылок: %d, блоков кода: %d, цитат: %d"
                         (:headers c) (:lists c) (:links c) (:code c) (:quotes c)))
        (println (str "Записано в " target))))))
