import sqlalchemy as db
from sqlalchemy.schema import DDL
import tkinter as tk
from tkinter import ttk

engine = db.create_engine('postgresql://chgk-user:noonewilleverguess@localhost/technical')
conn = engine.connect()


class Niceframe:
    def __init__(self, parent, inner_frame, name, header, runtext):
        self.inner_frame = inner_frame
        self.dbname = name
        self.header = header
        self.frame = tk.Frame(parent)
        self.frame.grid(row=0, column=0, sticky='news')
        self.param = ttk.Combobox(self.frame,
            values=['Просто посмотреть', 'Очистить', 'Добавить строку', 'Изменить строку', 'Удалить строку', 'Удалить с поиском'])
        self.param.set('Выберите действие:')
        self.param.bind('<<ComboboxSelected>>', self.instructions)
        self.param.grid(row=0, column=0, padx=10, pady=10)
        self.orderby = ttk.Combobox(self.frame,
                                values=header)
        self.orderby.grid(row=1, column=0, padx=10, pady=20)
        self.searchby = tk.Entry(self.frame)
        self.searchby.grid(row=1, column=1, padx=20, pady=20)
        self.run = tk.Button(self.frame, text=runtext, command=self.query)
        self.run.grid(row=1, column=2, padx=20, pady=20)

    def query(self):
        entries = {'', 'Выберите действие:', 'Сортировать:', 'Поиск...', 'ID...', 'Имя...', 'Профессия...', 'Адрес...',
                   'Дата...', 'Описание...', 'Музпауза...', 'Ссылка...', 'ID игры...', 'ID знатока...',
                   'ID телезрителя...', 'Статус...', 'Вопрос...', 'Ответ...', 'Реквизит...', 'Вознаграждение...'}
        parameters = {'Очистить': 'CLEAR', 'Добавить строку': 'ADD', 'Изменить строку': 'UPDATEROW', 'Удалить строку': 'DELETEROW', 'Удалить с поиском': 'DELETESEARCH'}
        columns = {'': 'id', 'ID': 'id', 'Имя': 'name', 'Профессия': 'profession', 'Адрес': 'address', 'Выиграно игр': 'won',
                   'Проиграно игр': 'lost', 'Выиграно раундов': 'won', 'Проиграно раундов': 'lost', 'Дата': 'date', 'Описание': 'info',
                   'Очки знатоков': 'expert_points', 'Очки телезрителей': 'viewer_points', 'Музыкальная пауза': 'music_pause',
                   'Ссылка': 'link', 'ID игры': 'game_id', 'ID знатока': 'expert_id', 'ID телезрителя': 'viewer_id',
                   'Статус': 'status', 'Вопрос': 'question', 'Ответ': 'answer', 'Реквизит': 'props', 'Вознаграждение': 'reward'}
        argline = ''

        if self.dbname == 'experts' or self.dbname == 'viewers':
            if self.id.get() not in entries: argline += 'id => ' + self.id.get() + ', '
            if self.name.get() not in entries: argline += 'name => \'' + self.name.get() + '\', '
            if self.prof.get() not in entries: argline += 'prof => \'' + self.prof.get() + '\', '
            if self.addr.get() not in entries: argline += 'addr => \'' + self.addr.get() + '\', '
        if self.dbname == 'games':
            if self.id.get() not in entries: argline += 'id => ' + self.id.get() + ', '
            if self.day.get() not in entries: argline += 'day => \'' + self.day.get() + '\', '
            if self.info.get() not in entries: argline += 'info => \'' + self.info.get() + '\', '
            if self.musicpause.get() not in entries: argline += 'musicpause => \'' + self.musicpause.get() + '\', '
            if self.link.get() not in entries: argline += 'link => \'' + self.link.get() + '\', '
        if self.dbname == 'lineups':
            if self.game_id.get() not in entries: argline += 'game_id => ' + self.game_id.get() + ', '
            if self.expert_id.get() not in entries: argline += 'expert_id => ' + self.expert_id.get() + ', '
            if self.status.get() not in entries: argline += 'status => \'' + self.status.get() + '\', '
        if self.dbname == 'rounds':
            if self.game_id.get() not in entries: argline += 'game_id => ' + self.game_id.get() + ', '
            if self.viewer_id.get() not in entries: argline += 'viewer_id => ' + self.viewer_id.get() + ', '
            if self.status.get() not in entries: argline += 'status => \'' + self.status.get() + '\', '
            if self.question.get() not in entries: argline += 'question => \'' + self.question.get() + '\', '
            if self.answer.get() not in entries: argline += 'answer => \'' + self.answer.get() + '\', '
            if self.props.get() not in entries: argline += 'props => \'' + self.props.get() + '\', '
            if self.reward.get() not in entries: argline += 'reward => ' + self.reward.get() + ', '
        if self.param.get() in parameters:
            argline += 'param => \'' + parameters[self.param.get()] + '\', '
        if self.orderby.get() in columns:
            argline += 'orderby => \'' + columns[self.orderby.get()] + '\', '

        if self.searchby.get() in entries:
            argline += 'searchby => \'\''
        else:
            argline += 'searchby => \'' + self.searchby.get() + '\''

        queryline = 'SELECT * FROM ' + self.dbname + '_func(' + argline + ');'
        try:
            data = conn.execute(queryline).fetchall()
            for child in self.inner_frame.winfo_children():
                child.destroy()
            self.datafill(data)
            self.popup('> Всё работает как надо')
        except:
            conn.execute('SELECT disconnect_on_error();')
            self.tkraise()
            self.popup('> Неверно построен запрос')

    def tkraise(self):
        self.frame.tkraise()
        self.param.set('Выберите действие:')
        self.searchby.delete(0, 'end'); self.searchby.insert(0, 'Поиск...')
        self.orderby.set('Сортировать:')
        if self.dbname == 'experts' or self.dbname == 'viewers':
            self.id.delete(0, 'end'); self.id.insert(0, 'ID...')
            self.name.delete(0, 'end'); self.name.insert(0, 'Имя...')
            self.prof.delete(0, 'end'); self.prof.insert(0, 'Профессия...')
            self.addr.delete(0, 'end'); self.addr.insert(0, 'Адрес...')
        if self.dbname == 'games':
            self.id.delete(0, 'end'); self.id.insert(0, 'ID...')
            self.day.delete(0, 'end'); self.day.insert(0, 'Дата...')
            self.info.delete(0, 'end'); self.info.insert(0, 'Описание...')
            self.musicpause.delete(0, 'end'); self.musicpause.insert(0, 'Музпауза...')
            self.link.delete(0, 'end'); self.link.insert(0, 'Ссылка...')
        if self.dbname == 'lineups':
            self.game_id.delete(0, 'end'); self.game_id.insert(0, 'ID игры...')
            self.expert_id.delete(0, 'end'); self.expert_id.insert(0, 'ID знатока...')
            self.status.delete(0, 'end'); self.status.insert(0, 'Статус...')
        if self.dbname == 'rounds':
            self.game_id.delete(0, 'end'); self.game_id.insert(0, 'ID игры...')
            self.viewer_id.delete(0, 'end'); self.viewer_id.insert(0, 'ID телезрителя...')
            self.status.delete(0, 'end'); self.status.insert(0, 'Статус...')
            self.question.delete(0, 'end'); self.question.insert(0, 'Вопрос...')
            self.answer.delete(0, 'end'); self.answer.insert(0, 'Ответ...')
            self.props.delete(0, 'end'); self.props.insert(0, 'Реквизит...')
            self.reward.delete(0, 'end'); self.reward.insert(0, 'Вознаграждение...')
        self.query()

    def datafill(self, data):
        for i in range(len(self.header)):
            tk.Label(self.inner_frame, text=self.header[i], justify='left', bd=5,
                     font='helvetica 10 underline').grid(row=0, column=i, sticky='nw')
        for i in range(len(data)):
            for j in range(len(data[0])):
                tk.Label(self.inner_frame, text=str(data[i][j]), justify='left', bd=5,
                         font='helvetica 10', wraplength=600).grid(row=i+1, column=j, sticky='nw')

    def popup(self, message):
        popup = tk.Label(self.frame, text=message, relief='groove', height=2, width=25, foreground='blue')
        popup.grid(row=1, column=3)

    def instructions(self, *args):
        if self.param.get() == 'Изменить строку' or self.param.get() == 'Удалить строку':
            self.popup('> Заполните весь ключ!')
        if self.param.get() == 'Добавить строку':
            self.popup('> Заполните все атрибуты!')
        if self.param.get() == 'Очистить':
            self.popup('> Осторожно!')
        if self.param.get() == 'Удалить с поиском':
            self.popup('> Не забудьте атрибут!')


def framebind(event):
    canvas.configure(scrollregion=canvas.bbox("all"), width=1400, height=650)
    canvas.configure(xscrollcommand=xscroll.set, yscrollcommand=yscroll.set)


def create_chgk(frame, menu):
    conn.execute('SELECT create_chgk();')
    eng = db.create_engine('postgresql://chgk-user:noonewilleverguess@localhost/chgk')
    temp = eng.connect()
    trigger_setup = open('external/trigger-setup.sql').read()
    temp.execute(DDL(trigger_setup))
    temp.close()
    eng.dispose()
    menu.entryconfig('Таблицы', state='normal')
    frame.tkraise()


def drop_chgk(menu):
    conn.execute('SELECT drop_chgk();')
    menu.entryconfig('Таблицы', state='disabled')


def fill_default(frame):
    conn.execute('SELECT fill_default();')
    frame.tkraise()


def clear_all(frame):
    conn.execute('SELECT clear_all();')
    frame.tkraise()


window = tk.Tk()
window.wm_title('"Что? Где? Когда?" - база данных')
sizex = 1420
sizey = 800
posx = 200
posy = 100
window.wm_geometry("%dx%d+%d+%d" % (sizex, sizey, posx, posy))

table = tk.Frame(window)
table.grid(row=1, column=0, sticky='news', pady=(10, 0))

canvas = tk.Canvas(table)
inner_frame = tk.Frame(canvas)
xscroll = tk.Scrollbar(table, orient='horizontal', command=canvas.xview)
yscroll = tk.Scrollbar(table, orient='vertical', command=canvas.yview)
xscroll.pack(side='bottom', fill='x')
yscroll.pack(side='right', fill='y')
canvas.pack(side='left', fill='x')
canvas.create_window(0, 0, anchor='nw', window=inner_frame)
inner_frame.bind("<Configure>", framebind)

experts = Niceframe(window, inner_frame, 'experts', ['ID', 'Имя', 'Профессия', 'Адрес', 'Выиграно игр', 'Проиграно игр'], 'Запрос в Знатоки')
viewers = Niceframe(window, inner_frame, 'viewers', ['ID', 'Имя', 'Профессия', 'Адрес', 'Выиграно раундов', 'Проиграно раундов'], 'Запрос в Телезрители')
games = Niceframe(window, inner_frame, 'games',
                  ['ID', 'Дата', 'Описание', 'Очки знатоков', 'Очки телезрителей', 'Музыкальная пауза', 'Ссылка'], 'Запрос в Игры')
lineups = Niceframe(window, inner_frame, 'lineups', ['ID игры', 'ID знатока', 'Статус'], 'Запрос в Составы')
rounds = Niceframe(window, inner_frame, 'rounds',
                   ['ID игры', 'ID телезрителя', 'Статус', 'Вопрос', 'Ответ', 'Реквизит', 'Вознаграждение'], 'Запрос в Раунды')

experts.id = tk.Entry(experts.frame)
experts.id.grid(row=0, column=1, padx=20, pady=10)
experts.name = tk.Entry(experts.frame)
experts.name.grid(row=0, column=2, padx=20, pady=10)
experts.prof = tk.Entry(experts.frame)
experts.prof.grid(row=0, column=3, padx=20, pady=10)
experts.addr = tk.Entry(experts.frame)
experts.addr.grid(row=0, column=4, padx=20, pady=10)

viewers.id = tk.Entry(viewers.frame)
viewers.id.grid(row=0, column=1, padx=20, pady=10)
viewers.name = tk.Entry(viewers.frame)
viewers.name.grid(row=0, column=2, padx=20, pady=10)
viewers.prof = tk.Entry(viewers.frame)
viewers.prof.grid(row=0, column=3, padx=20, pady=10)
viewers.addr = tk.Entry(viewers.frame)
viewers.addr.grid(row=0, column=4, padx=20, pady=10)

games.id = tk.Entry(games.frame)
games.id.grid(row=0, column=1, padx=20, pady=10)
games.day = tk.Entry(games.frame)
games.day.grid(row=0, column=2, padx=20, pady=10)
games.info = tk.Entry(games.frame)
games.info.grid(row=0, column=3, padx=20, pady=10)
games.musicpause = tk.Entry(games.frame)
games.musicpause.grid(row=0, column=4, padx=20, pady=10)
games.link = tk.Entry(games.frame)
games.link.grid(row=0, column=5, padx=20, pady=10)

lineups.game_id = tk.Entry(lineups.frame)
lineups.game_id.grid(row=0, column=1, padx=20, pady=10)
lineups.expert_id = tk.Entry(lineups.frame)
lineups.expert_id.grid(row=0, column=2, padx=20, pady=10)
lineups.status = tk.Entry(lineups.frame)
lineups.status.grid(row=0, column=3, padx=20, pady=10)

rounds.game_id = tk.Entry(rounds.frame)
rounds.game_id.grid(row=0, column=1, padx=20, pady=10)
rounds.viewer_id = tk.Entry(rounds.frame)
rounds.viewer_id.grid(row=0, column=2, padx=20, pady=10)
rounds.status = tk.Entry(rounds.frame)
rounds.status.grid(row=0, column=3, padx=20, pady=10)
rounds.question = tk.Entry(rounds.frame)
rounds.question.grid(row=0, column=4, padx=20, pady=10)
rounds.answer = tk.Entry(rounds.frame)
rounds.answer.grid(row=0, column=5, padx=20, pady=10)
rounds.props = tk.Entry(rounds.frame)
rounds.props.grid(row=0, column=6, padx=20, pady=10)
rounds.reward = tk.Entry(rounds.frame)
rounds.reward.grid(row=0, column=7, padx=20, pady=10)

defaultframe = games

mainmenu = tk.Menu(window)
tables = tk.Menu(mainmenu, tearoff=0)
tables.add_command(label='Знатоки', command=experts.tkraise)
tables.add_command(label='Телезрители', command=viewers.tkraise)
tables.add_command(label='Игры', command=games.tkraise)
tables.add_command(label='Составы', command=lineups.tkraise)
tables.add_command(label='Раунды', command=rounds.tkraise)
tables.add_command(label='Заполнить сохранённым пакетом данных', command=lambda: fill_default(defaultframe))
tables.add_command(label='Очистить всё', command=lambda: clear_all(defaultframe))
mainmenu.add_cascade(label='Таблицы', menu=tables)

base = tk.Menu(mainmenu, tearoff=0)
base.add_command(label='Создать базу данных', command=lambda: create_chgk(defaultframe, mainmenu))
base.add_command(label='Удалить базу данных', command=lambda: drop_chgk(mainmenu))
mainmenu.add_cascade(label='База данных', menu=base)
window.config(menu=mainmenu)

create_chgk(defaultframe, mainmenu)

window.mainloop()
