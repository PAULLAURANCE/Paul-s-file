from flask import Flask, render_template, request, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from sqlalchemy import text
from datetime import datetime

app = Flask(__name__)

# --- 1. 基础配置 ---
app.config['SECRET_KEY'] = 'sysu_secret_key'
# 请确保密码、库名无误
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://你的账户名:你的密码@localhost:3306/sysu_game_center'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
login_manager = LoginManager(app)
login_manager.login_view = 'login'

# --- 2. User类：用于兼容 Flask-Login (保持 Session 必须有此对象) ---
class User(UserMixin):
    def __init__(self, user_id, nickname, balance, user_level, email):
        self.user_id = user_id
        self.nickname = nickname
        self.balance = balance
        self.user_level = user_level
        self.email = email
    def get_id(self): return str(self.user_id)

@login_manager.user_loader
def load_user(user_id):
    sql = text("SELECT * FROM User WHERE user_id = :id")
    res = db.session.execute(sql, {"id": user_id}).fetchone()
    if res:
        # res 对象可以通过索引或者名称访问：res[0] 是 id, res[1] 是 nickname ...
        return User(res[0], res[1], res[3], res[2], res[4])
    return None

# --- 3. 业务路由 (全 SQL 实现) ---

# 3.1 登录
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email, pwd = request.form.get('email'), request.form.get('password')
        sql = text("SELECT * FROM User WHERE email = :e AND password = :p")
        res = db.session.execute(sql, {"e": email, "p": pwd}).fetchone()
        if res:
            login_user(User(res[0], res[1], res[3], res[2], res[4]))
            return redirect(url_for('index'))
        flash('邮箱或密码不匹配')
    return render_template('login.html')

# 3.2 注册
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        n, e, p, r = request.form.get('nickname'), request.form.get('email'), request.form.get('password'), request.form.get('role')
        # SQL 插入新用户
        db.session.execute(text("INSERT INTO User(nickname, email, password, balance) VALUES (:n, :e, :p, 0)"), {"n":n, "e":e, "p":p})
        if r == 'developer':
            db.session.execute(text("INSERT INTO Developer(dev_name, balance) VALUES (:n, 0)"), {"n": n})
        db.session.commit()
        return redirect(url_for('login'))
    return render_template('register.html')

@app.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('login'))

# 3.3 商城首页
@app.route('/')
def index():
    # SQL 获取所有游戏
    games = db.session.execute(text("SELECT * FROM Game")).fetchall()
    return render_template('index.html', games=games)

# 3.4 游戏详情页
@app.route('/game/<int:game_id>')
def detail(game_id):
    # SQL 查询游戏、DLC、平均评分
    game = db.session.execute(text("SELECT * FROM Game WHERE game_id = :id"), {"id": game_id}).fetchone()
    dlcs = db.session.execute(text("SELECT * FROM DLC WHERE game_id = :id"), {"id": game_id}).fetchall()
    avg = db.session.execute(text("SELECT AVG(score) FROM Rating WHERE game_id = :id"), {"id": game_id}).scalar()
    avg_score = round(float(avg), 1) if avg else "暂无评分"

    is_owned = False
    is_wished = False
    if current_user.is_authenticated:
        # 查是否购买 (SQL)
        o_sql = text("SELECT 1 FROM UserLibrary WHERE user_id=:u AND game_id=:g AND item_type='Game'")
        is_owned = True if db.session.execute(o_sql, {"u": current_user.user_id, "g": game_id}).fetchone() else False
        # 查愿望单 (SQL)
        w_sql = text("SELECT 1 FROM Wishlist WHERE user_id=:u AND game_id=:g")
        is_wished = True if db.session.execute(w_sql, {"u": current_user.user_id, "g": game_id}).fetchone() else False

    return render_template('detail.html', game=game, dlcs=dlcs, is_owned=is_owned, is_wished=is_wished, avg_score=avg_score)

# 3.5 购买逻辑 (事务级SQL)
@app.route('/buy/<string:item_type>/<int:item_id>')
@login_required
def buy(item_type, item_id):
    if item_type == 'Game':
        res = db.session.execute(text("SELECT price, dev_id, game_id FROM Game WHERE game_id=:id"), {"id":item_id}).fetchone()
    else:
        res = db.session.execute(text("SELECT d.price, g.dev_id, d.game_id FROM DLC d JOIN Game g ON d.game_id=g.game_id WHERE dlc_id=:id"), {"id":item_id}).fetchone()
    
    if float(current_user.balance) >= float(res[0]):
        # 扣钱、入账、写记录
        db.session.execute(text("UPDATE User SET balance = balance - :p WHERE user_id = :u"), {"p":res[0], "u":current_user.user_id})
        db.session.execute(text("UPDATE Developer SET balance = balance + :p WHERE dev_id = :d"), {"p":res[0], "d":res[1]})
        ins_lib = text("INSERT INTO UserLibrary(user_id, item_type, game_id, dlc_id) VALUES (:u, :t, :g, :d)")
        db.session.execute(ins_lib, {"u":current_user.user_id, "t":item_type, "g":res[2], "d":item_id if item_type=='DLC' else None})
        if item_type == 'Game': # 移除愿望单
            db.session.execute(text("DELETE FROM Wishlist WHERE user_id=:u AND game_id=:g"), {"u":current_user.user_id, "g":res[2]})
        db.session.commit()
        flash('资产已入库！')
    else: flash('资金匮乏，交易终止。')
    return redirect(url_for('library'))

# 3.6 个人库 (连表 SQL 查询)
@app.route('/library')
@login_required
def library():
    # 查拥有的游戏、愿望单列表、好友名单
    sql_mine = text("SELECT g.* FROM Game g JOIN UserLibrary l ON g.game_id=l.game_id WHERE l.user_id=:u AND l.item_type='Game'")
    games = db.session.execute(sql_mine, {"u":current_user.user_id}).fetchall()
    
    sql_wish = text("SELECT g.* FROM Game g JOIN Wishlist w ON g.game_id=w.game_id WHERE w.user_id=:u")
    wishlist = db.session.execute(sql_wish, {"u":current_user.user_id}).fetchall()
    
    sql_friends = text("""SELECT r.rel_id, u.nickname, u.email 
                          FROM Friendship r 
                          JOIN User u ON (CASE WHEN r.user_id = :uid THEN r.friend_id ELSE r.user_id END) = u.user_id 
                          WHERE r.user_id = :uid OR r.friend_id = :uid""")
    friends = db.session.execute(sql_friends, {"uid": current_user.user_id}).fetchall()

    return render_template('library.html', games=games, wished_games=wishlist, friends=friends)

# 3.7 评分
@app.route('/rate/<int:game_id>', methods=['POST'])
@login_required
def rate_game(game_id):
    score = request.form.get('score')
    db.session.execute(text("INSERT INTO Rating(user_id, game_id, score) VALUES (:u,:g,:s) ON DUPLICATE KEY UPDATE score=:s"), 
                       {"u":current_user.user_id, "g":game_id, "s":score})
    db.session.commit()
    return redirect(url_for('detail', game_id=game_id))

# 3.8 社交
@app.route('/add_friend', methods=['POST'])
@login_required
def add_friend():
    target_email = request.form.get('email')
    target = db.session.execute(text("SELECT user_id FROM User WHERE email = :e"), {"e": target_email}).fetchone()
    if target and target[0] != current_user.user_id:
        u1, u2 = sorted([current_user.user_id, target[0]])
        db.session.execute(text("INSERT IGNORE INTO Friendship(user_id, friend_id) VALUES (:u1,:u2)"), {"u1":u1, "u2":u2})
        db.session.commit()
    return redirect(url_for('library'))

@app.route('/remove_friend/<int:rel_id>')
@login_required
def remove_friend(rel_id):
    db.session.execute(text("DELETE FROM Friendship WHERE rel_id = :rid"), {"rid": rel_id})
    db.session.commit()
    return redirect(url_for('library'))

# 3.9 开发者、愿望单加/充值 (全 SQL)
@app.route('/developer')
@login_required
def developer():
    dev = db.session.execute(text("SELECT * FROM Developer WHERE dev_name=:n"), {"n":current_user.nickname}).fetchone()
    if dev:
        published = db.session.execute(text("SELECT * FROM Game WHERE dev_id=:d"), {"d":dev[0]}).fetchall()
        return render_template('developer.html', dev=dev, games=published)
    return "非开发者权限"

@app.route('/wishlist/add/<int:game_id>')
@login_required
def add_wishlist(game_id):
    db.session.execute(text("INSERT IGNORE INTO Wishlist(user_id, game_id) VALUES (:u, :g)"), {"u":current_user.user_id, "g":game_id})
    db.session.commit()
    return redirect(url_for('detail', game_id=game_id))

@app.route('/topup')
@login_required
def topup():
    db.session.execute(text("UPDATE User SET balance = balance + 500 WHERE user_id = :u"), {"u": current_user.user_id})
    db.session.commit()
    return redirect(url_for('library'))

if __name__ == '__main__':
    app.run(debug=True, port=5001)
