local stdio = require("@lune/stdio")
 
-- Prompting the user for basic input
local text: string = stdio.prompt("text", "Please write some text")
print("I got", text)