検索用のgem「ransack」を使ってみる

ransackはrails用の検索機能を実装するためのgemです。
比較的シンプルなコードで複雑な検索を実装することができます。
ransackの概要と使い方については[Ransackのススメ](http://qiita.com/items/9a95d91f2b97a08b96b0 "Ransackのススメ")を参照してください。
ここでは実際に使用するまでのサンプルを作ってみます。

####プロジェクトを作成

```terminal
rails new ransack_study -T --skip-bundle
cd ransack_study
```
localeとtimezoneを設定

```config/application.rb
require File.expand_path('../boot', __FILE__)
	〜〜 ( 中略 ) 〜〜
module RansackStudy
  class Application < Rails::Application
	〜〜 ( 中略 ) 〜〜
    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    config.time_zone = 'Tokyo'
    config.active_record.default_timezone = :local

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.default_locale = :ja

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"
	〜〜 ( 中略 ) 〜〜
  end
end

```


####ransackのインストール

Gemfileに追記

```terminal
vi Gemfile
```

```Gemfile
source 'https://rubygems.org'

gem 'rails', '3.2.11'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'sqlite3'
	
gem 'rails-i18n' # この行を追加(ransackには関係ないけどdate_select用)
gem 'ransack'	# この行を追加

〜〜( 以下 略 )〜〜
```

bundle installを実行

```terminal
bundle install
```

####今回のサンプル用にscaffold
ユーザーモデルと、ユーザーが紐づく掲示板モデルを作成します。

```terminal
rails g scaffold user name:string
rails g scaffold topic title:string content:text user:references
```

掲示板モデルでユーザーを登録するためにちょろっと修正

```app/models/topic.rb
class Topic < ActiveRecord::Base
  belongs_to :user
  attr_accessible :content, :title, :user_id #この行を修正
end
```

ユーザーをselectタグで選択できるように

```app/views/_form.html.erb
<%= form_for(@topic) do |f| %>
  〜〜 ( 中略 ) 〜〜
  <div class="field">
    <%= f.label :user %><br />
    <%= f.select :user_id, User.all.map { |u| [u.name, u.id] } %><!--この行を修正-->
  </div>
  <div class="actions">
    <%= f.submit %>
  </div>
<% end %>

```

一覧からcontentを削除し、created_atを追加、ユーザー名を表示するように変更

```app/views/index.html.erb
<h1>Listing topics</h1>

<table>
  <tr>
    <th>Title</th>
    <th>User</th>
    <th>Created At</th><!--この行を修正-->
    <th></th>
    <th></th>
    <th></th>
  </tr>

<% @topics.each do |topic| %>
  <tr>
    <td><%= topic.title %></td>
    <td><%= topic.user.name %></td><!--この行を修正-->
    <td><%= topic.created_at.strftime('%Y/%m/%d %H:%M') %></td><!--この行を修正-->
    <td><%= link_to 'Show', topic %></td>
    <td><%= link_to 'Edit', edit_topic_path(topic) %></td>
    <td><%= link_to 'Destroy', topic, method: :delete, data: { confirm: 'Are you sure?' } %></td>
  </tr>
<% end %>
</table>

<br />

<%= link_to 'New Topic', new_topic_path %>

```

詳細でユーザー名を表示するように変更

```app/views/topic/show.html.erb
  〜〜 ( 中略 ) 〜〜
<p>
  <b>User:</b>
  <%= @topic.user.name %><!--この行を修正-->
</p>
  〜〜 ( 中略 ) 〜〜
```


とりあえず実行してみる

```terminal
rake db:migrate
rails s
```

[http://localhost:3000/users](http://localhost:3000/users)でユーザーを適当に登録
[http://localhost:3000/topics](http://localhost:3000/topics)で掲示板を何件か登録

今の画面はこんな感じ。
![ユーザー一覧](http://f.cl.ly/items/2K063w2S320O2K0t1Y0r/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88%202013-05-08%2013.54.14.png)
![掲示板一覧](http://f.cl.ly/items/310t120J332v2X0u4303/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88%202013-05-08%2014.14.30.png)

ここまでで準備は完了です。
ここからは実際にransackの機能を使って検索フォームを作成してきます。


####ransackの基本的な使い方
ransackは基本的にはsearchメソッドで条件を指定し、resultで結果を返します。

```ruby
User.search(name_cont: 'ほげ').result
```
上の処理を実行すると次のようなSQL文を発行し、ActiveRecord::Relationオブジェクトを返します。

```
SELECT "users".* FROM "users" WHERE ("users"."name" LIKE '%ほげ%')
```

また、ransackには検索フォーム用のフォームビルダーも用意されています、
今回はそれを利用して掲示板の検索フォームを作成していきます。

####search_form_forの利用
TopicsControllerでsearchオブジェクトを生成

```app/controllers/topics_controller.rb
class TopicsController < ApplicationController
  # GET /topics
  # GET /topics.json
  def index
    @search = Topic.search(params[:q]) # この行を追加
    @topics = @search.result #この行を修正

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @topics }
    end
  end
  〜〜 ( 中略 ) 〜〜
end
```

search_form_forを利用して検索フォームを作成
まずはtopicのtitleを前後あいまい検索する場合index.html.erbを以下のように修正

```app/views/topics/index.html.erb
<h1>Listing topics</h1>
<%= search_form_for @search do |f| %>
  <%= f.label :title_cont, 'タイトル' %>
  <%= f.text_field :title_cont %>
  <div>
    <%= f.submit '検索する' %>
  </div>
<% end %>
  〜〜 ( 以下 略 ) 〜〜
```

###以上

これだけtitleの曖昧検索が実装されます。
動かしてみるとこんな感じになってると思います。

![掲示板一覧検索語](http://f.cl.ly/items/1T0I0n0k3Q2e1D0f1p2Z/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88%202013-05-08%2014.49.02.png)

ここからはindex.htmlを追加するだけで検索処理を実装することが可能です。
試しに作成日の範囲指定を追加してみます。
index.html.erbを以下のように修正します。

```app/views/topics/index.html.erb
<h1>Listing topics</h1>
<%= search_form_for @search do |f| %>
  <%= f.label :title_cont, 'タイトル' %>
  <%= f.text_field :title_cont %>
  <!--ここから追加-->
  <br />
  <%= f.label :created_at, '作成日' %>
  <%= f.date_select :created_at_gteq, include_blank: true %>〜
  <%= f.date_select :created_at_lteq, include_blank: true %>
  <!--ここまで追加-->
  <div>
    <%= f.submit '検索する' %>
  </div>
<% end %>
  〜〜 ( 以下 略 ) 〜〜
```

動かしてみると以下のようになり、作成日での絞込みが実装されました。

![掲示板一覧日付範囲指定](http://f.cl.ly/items/1Z3B0s1O213y3q1j1f0c/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88%202013-05-08%2015.05.09.png)

日付の指定をした場合に発行されるSQLを確認してみます。

```
SELECT "topics".* FROM "topics" WHERE (("topics"."title" LIKE '%について%' AND "topics"."created_at" >= '2013-05-01 00:00:00.000000' AND "topics"."created_at" <= '2013-05-09 00:00:00.000000'))
```

このままではtoのほうの日付の条件が指定した日付の 00:00:00までしか対象になりません。
日付で絞り込むなら 23:59:59までを検索対象にしたいですよね。
なので、以下のようなファイル(config/initializers/ransack.rb)を作成します。

```config/initializers/ransack.rb
Ransack.configure do |config|
  config.add_predicate 'lteq_end_of_day',
                       :arel_predicate => 'lteq',
                       :formatter => proc { |v| v.end_of_day },
                       :compounds => false
end
```
formatterを指定し、index.html.erbも以下のように修正します。

```app/views/topics/index.html.erb
<h1>Listing topics</h1>
<%= search_form_for @search do |f| %>
  <%= f.label :title_cont, 'タイトル' %>
  <%= f.text_field :title_cont %>
  <br />
  <%= f.label :created_at, '作成日' %>
  <%= f.date_select :created_at_gteq, include_blank: true %>〜
  <%= f.date_select :created_at_lteq_end_of_day, include_blank: true %><!--この行を修正-->
  <div>
    <%= f.submit '検索する' %>
  </div>
<% end %>
  〜〜 ( 以下 略 ) 〜〜
```

ここでサーバーを一度再起動し、再度検索をし発行されるSQLを確認します。

```
SELECT "topics".* FROM "topics" WHERE (("topics"."title" LIKE '%について%' AND "topics"."created_at" >= '2013-05-01 00:00:00.000000' AND "topics"."created_at" <= '2013-05-08 23:59:59.999999'))
```

いい感じですね♪

最後に、関連するテーブルの項目での絞込みも試してみます。
topicsにひもづくユーザの名前で前後あいまい検索を行います。
index.html.erbを以下のように修正します。

```app/views/topics/index.html.erb
<h1>Listing topics</h1>

```app/views/topics/index.html.erb
<h1>Listing topics</h1>
<%= search_form_for @search do |f| %>
  <%= f.label :title_cont, 'タイトル' %>
  <%= f.text_field :title_cont %>
  <br />
  <%= f.label :created_at, '作成日' %>
  <%= f.date_select :created_at_gteq, include_blank: true %>〜
  <%= f.date_select :created_at_lteq_end_of_day, include_blank: true %>
  <!--ここから追加-->
  <br />
  <%= f.label :user, 'ユーザー' %>
  <%= f.text_field :user_name_cont %>
  <!--ここまで追加-->
  <div>
    <%= f.submit '検索する' %>
  </div>
<% end %>
  〜〜 ( 以下 略 ) 〜〜
```

実行すると以下のようになり、ユーザー名での絞込みが実装できましたね。

![掲示板一覧ユーザー名指定](http://f.cl.ly/items/0V1W2U0W3T3I0d211h3r/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88%202013-05-08%2015.19.08.png)

####ソートの実装
ransackにはソート用のhelperも用意されています。
それらを利用して掲示板一覧にソートを実装してみます。これもviewの修正だけで実装することが可能です。
index.html.erbのtableのヘッダーを以下のように修正します。

```app/views/topics/index.html.erb
<h1>Listing topics</h1>
  〜〜 ( 中略 ) 〜〜
<table>
  <tr>
    <th><%= sort_link(@search, :title, 'タイトル') %></th><!--この行を修正-->
    <th><%= sort_link(@search, :user_name, 'ユーザー') %></th><!--この行を修正-->
    <th><%= sort_link(@search, :created_at, '作成日時') %></th><!--この行を修正-->
    <th></th>
    <th></th>
    <th></th>
  </tr>
  〜〜 ( 以下 略 ) 〜〜
```
これで実行すると、ヘッダーがリンクになりクリックするとソートが実装されていることがわかります。

![掲示板一覧ソート](http://f.cl.ly/items/073D2q2U041I0J291E3L/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88%202013-05-08%2015.29.53.png)

####まとめ
ransackとransackのフォームビルダーを利用することで、比較的複雑な検索条件もほぼviewを修正するだけで実装することができました。動的に検索条件を作成することもview側を動的に作成するだけで可能ですので比較的簡単に実装できるかと思います。それらのチュートリアルがRailsCasts([#370 Ransack](http://railscasts.com/episodes/370-ransack?language=ja&view=asciicast))にありますので、そちらを参照してみてください。

####今回のソース
今回のソースは以下で公開しています。
LuckOfWise/ransack_study https://github.com/LuckOfWise/ransack_study


