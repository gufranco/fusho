function hexval(digit) {
  return index("0123456789abcdef", tolower(digit)) - 1
}

function rgb(colour) {
  if (colour == "") {
    return ""
  }
  return (hexval(substr(colour, 2, 1)) * 16 + hexval(substr(colour, 3, 1))) ";" \
    (hexval(substr(colour, 4, 1)) * 16 + hexval(substr(colour, 5, 1))) ";" \
    (hexval(substr(colour, 6, 1)) * 16 + hexval(substr(colour, 7, 1)))
}

function paint(text, colour, bold) {
  if (colour == "" && !bold) {
    return text
  }
  return "\033[" (bold ? "1" : "0") (colour == "" ? "" : ";38;2;" rgb(colour)) "m" text "\033[0m"
}

function plain(text) {
  sub(/^@(ok|warn|bad|acc|mut):/, "", text)
  return text
}

function tint(text) {
  if (text ~ /^@ok:/) { return ok }
  if (text ~ /^@warn:/) { return warn }
  if (text ~ /^@bad:/) { return bad }
  if (text ~ /^@acc:/) { return acc }
  if (text ~ /^@mut:/) { return mut }
  return txt
}

function pad(count,   out) {
  out = ""
  while (count-- > 0) {
    out = out " "
  }
  return out
}

{
  rows[NR] = $0
  for (column = 1; column <= NF; column++) {
    if (length(plain($column)) > width[column]) {
      width[column] = length(plain($column))
    }
  }
  if (NF > columns) {
    columns = NF
  }
}

END {
  total = 0
  for (column = 1; column <= columns; column++) {
    total += width[column] + (column > 1 ? 3 : 0)
  }
  for (row = 1; row <= NR; row++) {
    count = split(rows[row], cell, "\t")
    line = ""
    for (column = 1; column <= columns; column++) {
      value = column <= count ? cell[column] : ""
      shown = plain(value)
      colour = row == 1 ? acc : tint(value)
      line = line (column > 1 ? "   " : "") paint(shown, colour, row == 1) pad(width[column] - length(shown))
    }
    print line
    if (row == 1) {
      print paint(rule(total), mut, 0)
    }
  }
}

function rule(count,   out) {
  out = ""
  while (count-- > 0) {
    out = out dash
  }
  return out
}
