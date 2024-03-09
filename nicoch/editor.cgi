#!/usr/bin/perl
use CGI;

print <<"HEAD";
Content-type: text/html

HEAD

#http://jsfiddle.net/ginpei/kutUL/?utm_source=website&utm_medium=embed&utm_campaign=kutUL
print <<"EOF";
<!DOCTYPE html>
<html><head>
<title>Editor</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<meta name="viewport" content="width=device-width, user-scalable=yes,initial-scale=1.0" />
<style type="text/css">
html, body {
  height:100%;
  margin:0;
  box-sizing: border-box;
  padding: 1px;
 }
.fix-height {
  box-sizing: border-box;
  height: 100%;
}
.fix-width {
  box-sizing: border-box;
  width: 100%;
}
.editor {
  box-sizing: border-box;
  height: 100%;
}
.container{
  display: grid;
  grid-template-rows: auto 1fr;
  height: 100%;
}
.menubar {
  grid-row: 1/2;
}
.menubar input {
}
.main {
  grid-row: 2/3;
  height: 100%;
}
form {
  margin:0;
}
</style>
</head>
<body>
<script>
function CleanRegex(){
const tc=document.querySelector("textarea");
let text=tc.value;
text=text.replace(/\\?.+\$/gm,"");
tc.value=text;
}
</script>
<div class="editor">
<form action="modify.cgi" method="post" style="height: 100%;">
<div class="container">
<div class="menubar">
<input type="submit" value="Save" />
<input type="reset" value="Reset" />
<input type="button" value="Remove \?.+" onclick="CleanRegex();" />
<input type="hidden" name="op" value="edit" />
</div>
<div class="main">
<textarea name="a1" class="fix-height fix-width">
EOF

open FILEIN, "<", "/etc/nicochcgi/chlist.txt" or die "error";
while(<FILEIN>){
s/&/&amp;/g;
s/</&lt;/g;
s/>/&gt;/g;
print;
}
close(FILEIN);

print <<"EOF";
</textarea>
</div></div>
</form></div></body>
</html>
EOF
