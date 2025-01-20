# This AWK script redacts sensitive information from a text file if the sensitive 
# information is enclosed in "{{<redact>}}" and "{{</redact>}}" shortcodes.

# AWK scripts typically start with a BEGIN block, 
# which is executed once before the input is read.
BEGIN {
  # RS is the record separator. It defines how AWK splits the input into records.
  # Here, it's set to "{{</redact>}}", so AWK will treat each occurrence of 
  # "{{</redact>}}" as the end of a record.
  RS="{{</redact>}}"; 

  # FS is the field separator. It defines how AWK splits each record into fields.
  # Here, it's set to "{{<redact>}}", so AWK will treat each occurrence of 
  # "{{<redact>}}" as the start of a field.
  FS="{{<redact>}}";
}

# This block is executed for each record in the input.
{
  # gsub is a function that globally replaces occurrences of the first argument with 
  # the second argument in the third argument.
  # Here, it replaces each character (.) in the second field ($2) with an block (█) 
  # https://www.ascii-code.com/CP437/219
  t = gsub(/./,"█",$2); 

  # printf is a function that prints formatted output.
  # Here, it prints the first field ($1) followed by the redacted text.
  # If the number of characters replaced (t) is greater than 0, the redacted text is
  # enclosed in a verbatim environment. Otherwise, the redacted text is printed as is.
  # See: https://tex.stackexchange.com/questions/534342/how-to-use-block-box-drawing-characters-in-latex
  if (t > 0) {redacted = "`\\begin{verbatim}"$2"\\end{verbatim}`{=latex}";} else {redacted = $2;}
  printf "%s%s", $1, redacted;
}

