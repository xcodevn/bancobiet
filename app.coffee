express = require 'express'

console.log "Setting up database"
sqlite3 = require 'sqlite3'
db = new sqlite3.Database 'data.db'

try
  db.serialize =>
      db.run 'CREATE TABLE IF NOT EXISTS tb_post (id INTEGER PRIMARY KEY AUTOINCREMENT, date DATETIME, text TEXT, source TEXT, status TEXT)'

      db.run 'CREATE TABLE IF NOT EXISTS tb_subscriber (email TEXT PRIMARY KEY, token TEXT)'
catch er
  console.log "Error"

app = express()
logger = require 'morgan'
bodyParser = require 'body-parser'

errorHandler = require 'errorhandler'

app.use express.static __dirname + '/public'

cookieParser = require 'cookie-parser'
session      = require 'express-session'
captcha      = require 'captcha'
app.use cookieParser()
app.use session({ secret: 'thong tin bi mat khong ai co the biet duoc', name: 'sid', cookie: { maxAge: 600000}})

app.use captcha {url: '/capcha.jpg?.*', color:'#6064cd', background: '#fff' }

app.use logger()
app.use errorHandler({ dumpExceptions: false, showStack: false })
app.use bodyParser()



nodemailer = require 'nodemailer'
smtpTransport = nodemailer.createTransport 'SMTP',{service:"Gmail",auth:{user:"noreply.bancobiet@gmail.com",pass:"xxxxxxxxxxxx"}}

sendEmail = (subject, msg, des, time=4) ->
  mailOptions = {
    from: "no.reply <noreply.bancobiet.gmail.com>",
    to: des,
    subject: subject,
    html: msg
  }

  smtpTransport.sendMail mailOptions, (err, res) ->
    if err?
      console.log err
      console.log 'Retry'
      if time > 0
        sendEmail subject, msg, des, time-1 
    else
      console.log 'Message sent'


getFullURL = (req) ->
  "#{req.protocol}://#{req.get 'Host'}#{req.path}"

app.set 'views', __dirname + '/views'
app.set 'view engine', 'jade'

requireAdmin = (req, res, next) ->
  if req.session.admin?
    next()
  else
    res.render 'error'

app.get '/ping', (req, res) ->
  res.send 'pong'

app.get '/boaimabietduoc', (req, res) ->
  req.session.admin = true
  res.redirect '/admin'

app.get '/more', (req, res) ->
  db.get 'SELECT * FROM tb_post WHERE status = "ACCEPTED" ORDER BY RANDOM() LIMIT 1', (err, row) ->
    if err? or not row?
      res.render 'error'
    else
      res.redirect "/post/#{row.id}"

app.get '/new', (req, res) ->
  res.render 'new', {}

app.post '/new', [], (req, res) ->
  usertext = ""
  if req.body.usertext?
    usertext = req.body.usertext
  source = ""
  if req.body.source?
    source = req.body.source

  if usertext.length > 0
    db.run "INSERT INTO tb_post (date, text, source, status) VALUES (datetime(), ?, ?,?)", usertext, source, "NEWPOST", (err) ->
      if err?
        console.log err
        res.render 'error'
    res.render 'new_ok',{}
  else
    res.render 'new', {}

app.get '/', (req, res) ->
  db.get 'SELECT * FROM tb_post WHERE status = "ACCEPTED" ORDER BY RANDOM() LIMIT 1', (err, row) ->
    if err?
      res.render 'error'
    else
      res.render 'index', {row: row, url: getFullURL(req)}

app.get '/error', (req, res) ->
  res.render 'error', {}

app.get '/admin', requireAdmin, (req, res) ->
  db.all "SELECT * FROM tb_post WHERE status = ? ORDER BY date desc", "NEWPOST", (err, rows) ->
    if err?
      console.log err
      res.render 'error', {}
    else
      res.render 'admin', {"rows": rows}

app.get '/admin-all', requireAdmin, (req, res) ->
  db.all "SELECT * FROM tb_post", (err, rows) ->
    if err?
      console.log err
      res.render 'error', {}
    else
      res.render 'admin', {"rows": rows}

app.param (name, fn) ->
  if fn instanceof RegExp
    (req, res, next, val) ->
      captures = undefined
      if captures = fn.exec(String(val))
        req.params[name] = captures
        next()
      else
        next "route"
      return

app.param('id', /^\d+$/)

app.get '/accept/:id', requireAdmin, (req, res) ->
  db.run 'UPDATE tb_post SET status = ? WHERE id = ?', "ACCEPTED", req.params.id[0], (err) =>
    if err?
      console.log err
      res.render 'error'
    else
      db.each 'SELECT * from tb_subscriber', (err, row) =>
        if err?
          res.render 'error'
        else
          url = req.protocol + "://" + req.get('Host') + "/post/" + req.params.id[0]
          unurl = req.protocol + "://" + req.get('Host') + "/unsubscribe/" + row.token
          msg = """Xin chào,<br /><br />
          Chúng tôi có một điều thú vị mới dành cho bạn tại #{url} <br /> <br />
          Xin cám ơn,<br />
          Robot :-) <br /> <br />
          P.s: Nhấn vào <a href="#{unurl}">unsubscribe</a> để không nhận email thông báo trong tương lai.
          """
          sendEmail "Bài viết mới", msg, row.email

      res.redirect '/admin'

app.get '/reject/:id', requireAdmin, (req, res) ->
  db.run 'UPDATE tb_post SET status = ? WHERE id = ?', "NEWPOST", req.params.id[0], (err) ->
    if err?
      console.log err
      res.render 'error'
  res.redirect '/admin'

app.get '/post/:id', (req, res) ->
  db.get "SELECT * FROM tb_post WHERE status = ? AND id = ?", "ACCEPTED", req.params.id[0], (err, row) ->
    if err? or not row?
      res.render 'error'
    else
      res.render 'post', {row: row, url: getFullURL(req)}

app.get '/delete/:id', requireAdmin, (req, res) ->
  db.run 'DELETE FROM tb_post WHERE id = ?', req.params.id[0], (err) ->
    if err?
      console.log err
      res.render 'error'
  res.redirect '/admin'

app.get '/edit/:id', requireAdmin, (req, res) ->
  db.get 'SELECT  id, text, source FROM tb_post WHERE id = ?', req.params.id[0], (err, row) ->
    if err?
      console.log err
      res.render 'error'
    else
      res.render 'edit', {row: row}

app.post '/edit/:id', requireAdmin, (req, res) ->
  db.run 'UPDATE tb_post SET text = ?, source = ? WHERE id = ?', req.body.usertext, req.body.source, req.params.id[0], (err) ->
    if err?
      console.log err
      res.render 'error'
    else
      res.redirect '/admin'

app.post '/subscribe', (req, res) ->
  if req.body.email?
    rd = req.body.email + ":" + String(Math.random())
    db.run 'INSERT INTO tb_subscriber VALUES (?, ?)', req.body.email, rd, (err) ->
      if err?
        res.render 'error'
      else
        res.render 'subscribe_ok'
  else
    res.render 'error'

app.param('token', /^.+$/)
app.get '/unsubscribe/:token', (req, res) ->
  db.run 'DELETE FROM tb_subscriber WHERE token = ? ', req.params.token[0], (err) ->
    if err?
      res.render 'error'
    else
      res.render 'unsubscribe_ok'

app.get '*', (req, res) ->
  res.render 'error', {}

app.post '*', (req, res) ->
  res.render 'error', {}

server = app.listen 3000, ->
  console.log "Server is listening on port #{server.address().port}"



