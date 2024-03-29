namespace :analytics_lens do
  namespace :all do
    desc "F値、焦点距離を全て解析する"
    task lens_info: :environment do
      MShopInfo.select(:id, :shop_name).where(disabled: false).all.each do |m|
        `bundle exec rails analytics_lens:lens_info[#{m.id}] RAILS_ENV=#{Rails.env}`
      end
    end

    desc "Googleの結果から重要度ランキングを全て抽出する"
    task word_ranking: :environment do
      MShopInfo.select(:id, :shop_name).where(disabled: false).all.each do |m|
        `bundle exec rails analytics_lens:word_ranking[#{m.id}] RAILS_ENV=#{Rails.env}`
      end
    end

    desc "タグ付けを全てに行う"
    task add_tags: :environment do
      MShopInfo.select(:id, :shop_name).where(disabled: false).all.each do |m|
        `bundle exec rails analytics_lens:add_tags[#{m.id}] RAILS_ENV=#{Rails.env}`
      end
    end

    desc "タグの関連文字を補充する(実行するたびに上書きする)"
    task compensate_tag_relate: :environment do
      MShopInfo.select(:id, :shop_name).where(disabled: false).all.each do |m|
        `bundle exec rails analytics_lens:compensate_tag_relate[#{m.id}] RAILS_ENV=#{Rails.env}`
      end
    end
  end

  namespace :reset do
    desc "リセット後にGoogleの結果から重要度ランキングを全て抽出する"
    task word_ranking: :environment do
      MShopInfo.select(:id, :shop_name).where(disabled: false).all.each do |m|
        AnalyticsLensInfo.includes(:m_lens_info).joins(:m_lens_info).where("m_lens_infos.m_shop_info_id"=> m.id).update_all(ranking_words: nil)
        `bundle exec rails analytics_lens:word_ranking[#{m.id}] RAILS_ENV=#{Rails.env}`
      end
    end

    desc "リセット後にタグ付けを全てに行う"
    task add_tags: :environment do
      MShopInfo.select(:id, :shop_name).where(disabled: false).all.each do |m|
        MLensInfo.where(m_shop_info_id: m.id).update_all(tags: nil)
        `bundle exec rails analytics_lens:add_tags[#{m.id}] RAILS_ENV=#{Rails.env}`
      end
    end
  end

  desc "F値、焦点距離を解析する"
  task :lens_info, ['target_shop_id'] => :environment do |task, args|
    TaskCommon::set_log 'analytics_lens/lens_info'

    TaskSwitchLensInfo::fetch args[:target_shop_id].to_i
  end

  desc "レンズのGoogleの見解を解析する(※ショップ指定なし)"
  task lens_related_word_with_google: :environment do |task, args|
    TaskCommon::set_log 'analytics_lens/lens_related_word_with_google'

    $session = TaskCommon::get_session

    # Googleに関連性を検索しに行く
    def search_google_for_lens(search_word)
      begin
        # ”レンズ”をつけて検索結果をいい感じにする
        # レンズ Nikon ニッコール 85/2L
        $session.visit "https://www.google.co.jp/search?q=#{URI.escape("レンズ " + search_word.gsub(/レンズ|ﾚﾝｽﾞ/, ''))}"

        # 関連性と強調単語
        {related_words: $session.all(:css, "._Bmc").map{|r| r.text}, match_words: $session.all(:css, "b").map{|r| r.text}}
      rescue => e
        Rails.logger.error e.message
        return {related_words: [], match_words: []}
      end
    end

    query = <<-SQL
      SELECT mli.id, mli.lens_name
      FROM m_lens_infos as mli
      LEFT OUTER JOIN analytics_lens_infos AS ali ON ali.m_lens_info_id = mli.id
      WHERE ali.id IS NULL
      LIMIT 30
    SQL

    analytics_lnes_infos = []
    ActiveRecord::Base.connection.select_all(query).to_a.each do |lens_info|
      TaskCommon::access_sleep

      search_result = search_google_for_lens lens_info["lens_name"]

      analytics_lnes_infos << {m_lens_info_id: lens_info["id"], google_related_words: search_result[:related_words].join(','), google_match_words: search_result[:match_words].join(',')}

    end

    AnalyticsLensInfo.import analytics_lnes_infos.map{|r| AnalyticsLensInfo.new(r)}
  end

  desc "Googleの結果から重要度ランキングを抽出する"
  task :word_ranking, ['target_shop_id'] => :environment do |task, args|
    TaskCommon::set_log 'analytics_lens/word_ranking'

    shop_id = args[:target_shop_id].to_i

    query = <<-SQL
      SELECT ali.id, ali.google_match_words
      FROM m_lens_infos as mli
      INNER JOIN analytics_lens_infos AS ali ON ali.m_lens_info_id = mli.id
      WHERE ali.ranking_words IS NULL
      AND mli.m_shop_info_id = #{shop_id}
    SQL

    analytics_lens_infos = []
    ActiveRecord::Base.connection.select_all(query).to_a.each do |r|
      ranking = LensInfoAnalysis::create_ranking r["google_match_words"]

      AnalyticsLensInfo.find(r["id"]).update(ranking_words: ranking.keys.join(','))
    end
  end

  desc "タグ付けを行う"
  task :add_tags, ['target_shop_id'] => :environment do |task, args|
    TaskCommon::set_log 'analytics_lens/add_tags'

    # タグ一覧を取得する
    m_proper_nouns = MProperNoun.fetch_tags

    shop_id = args[:target_shop_id].to_i

    m_lens_info = MLensInfo.select(:ranking_words).includes(:analytics_lens_info).joins(:analytics_lens_info, :m_shop_info).where(tags: nil).where("m_shop_infos.id = ?", shop_id).all

    m_lens_info.each_slice(100).to_a.each do |m_lens_info_group|
      m_lens_info_group.each do |r|
        match_tags = []
        next unless r.analytics_lens_info.ranking_words.present?

        r.analytics_lens_info.ranking_words.split(',').each do |word|
          m_proper_nouns.each do |noun_id, target_words|
            target_words.split(',').each do |target_word|
              if word == target_word
                match_tags << noun_id
              end
            end
          end
        end

        next if match_tags.size == 0

        uniq_tags = match_tags.uniq

        r.tags = uniq_tags.sort.join(',')

        r.designation = uniq_tags.find{|uniq_tag| MLensGenre.is_designation?(uniq_tag)}
        r.maker = uniq_tags.find{|uniq_tag| MLensGenre.is_maker?(uniq_tag)}

        unless r.save!
          Rails.logger.error "セーブエラー(#{r.id})：#{r.messages}"
        end
      end
      # COMMENT: 負荷を感じる場合は指定回数で終了させる
      # break
    end
  end

  desc "タグの関連文字を補充する(実行するたびに上書きする)"
  task :compensate_tag_relate, ['target_shop_id'] => :environment do |task, args|
    TaskCommon::set_log 'analytics_lens/compensate_tag_relate'

    # タグ一覧を取得する
    m_proper_nouns = MProperNoun.fetch_tags true

    shop_id = args[:target_shop_id].to_i

    analytics_lens_infos = AnalyticsLensInfo.select(:ranking_words).includes(:m_lens_info).joins(:m_lens_info).where("m_lens_infos.m_shop_info_id"=> shop_id).all

    analytics_lens_infos.each do |analytics_lens_info|
      ranking_words = analytics_lens_info.ranking_words

      m_proper_nouns.each do |noun_id, target_words|
        target_words.split(',').each do |target_word|
          next unless target_word.present?

          if ranking_words.match /#{target_word}/
            m_proper_noun = MProperNoun.find noun_id
            if m_proper_noun.relate_name.present?
              m_proper_noun.relate_name = (m_proper_noun.relate_name + ',' + ranking_words).split(',').uniq.join(',')
            else
              m_proper_noun.relate_name = ranking_words
            end

            unless m_proper_noun.save!
              Rails.logger.error "セーブエラー(#{noun_id})：#{m_proper_noun.messages}"
            end

            next
          end
        end
      end
    end
  end

end