const createError = require('http-errors');
const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const logger = require('morgan');
const session = require('express-session');
const flash = require('connect-flash');
const cors = require('cors');

var indexRouter = require('./routes/index');
var makananRouter = require('./routes/makanan');
var authRouter = require('./routes/auth');

const app = express();
app.use(cors());

app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');

app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));
app.use(flash());

// session (mirip fasilitasin)
app.use(session({
    secret: 'shurdikelompok', // ganti di .env untuk production
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 60 * 60 * 1000 } // 1 jam
}));

// expose session ke semua view (navbar lama pakai ini)
app.use((req, res, next) => {
    res.locals.session = req.session; // <— penting untuk snippet navbar lama
    res.locals.success = req.flash('success');
    res.locals.error = req.flash('error');
    next();
});

// routes (sesuai fasilitasin: logres dipasang di '/')
app.use('/', indexRouter);
app.use('/api/makanan', makananRouter);
app.use('/api/auth', require('./routes/auth'));

// 404
app.use(function(req, res, next) { next(createError(404)); });

// error handler
app.use(function(err, req, res, next) {
    res.locals.message = err.message;
    res.locals.error = req.app.get('env') === 'development' ? err : {};
    res.status(err.status || 500);
    res.render('error');
});

module.exports = app;