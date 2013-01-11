# -*- coding: utf-8 -*-
## Created  : 2012/12/07 -Y.Kimura
## Modified : 2012/12/19 -Y.Kimura
## Ruby Ver : 1.9.2
## get Events (of Dropbox) information
##
## Methods:
##    date: yyyy-mm-dd (str)
##    page: int
##  set_cookie
##  get_events_html( date, page )
##  login
##  get_events_list( date, page )
##  get_all_events
##  set_csv_events

## push to github
## "dropbox_event_analyzer"
###
require 'open-uri'
require 'kconv'
require 'mechanize'
###

class Dropbox_Events

  def initialize
    @TODAY = Time.now.strftime("%Y-%m-%d")
    @dropbox_url = "https://www.dropbox.com/"
    @events_url = URI.parse( @dropbox_url + "events" )
    @login_url = URI.parse( @dropbox_url + "login")

    @agent = Mechanize.new

    user_agent = "Mac Mozilla"
    @agent.user_agent_alias = user_agent
    set_cookie
  end

  def set_cookie
    begin
      cookie_str = @agent.cookie_jar.load("dropbox_cookie.yaml")
      return cookie_str
    rescue
      return nil
    end
  end

  def get_events_html(date = "", page_num = 0)
    # set page&date
    if(date != "")
      events_date = @dropbox_url.to_s + "next_events?cur_page=#{page_num.to_s}&date=#{date}"
      @events_url = URI.parse(events_date)
    end

    # get HtmlOfEvents
    @agent.get(@events_url)
    events_html = @agent.page

    if(events_html.title =~ /Sign/ || events_html.title=~ /サイン/ )
      login
      events_html = get_events_html(date, page_num)
    end
    return events_html #.body
  end

  def login
    @agent.cookie_jar.clear!

    puts "Input Dropbox ID (MailAddress) : "
    mail_address = gets
    puts "Input Dropbox Password : "
    password = gets

    @login_page = @agent.get(@login_url)
    @login_page.form_with(:action => "/login"){|form|
      form.field_with(:name => "login_email"){|field|
        field.value = mail_address.chomp
      }
      form.field_with(:name => "login_password"){|field|
        field.value = password.chomp
      }
      form.click_button
    }

    @agent.cookie_jar.save_as("dropbox_cookie.yaml")
  end

  ## return list of [action,date,path]
  def get_events_list(date = "", page_num = 0)
    match_date = date.gsub("-","/")
    eventlist = Array.new

    html = get_events_html(date, page_num)
    list = html.search("tr")
    list.each{|tr|
      td = tr.search("td")
      # file path from <... title="???">
      td[1].to_s =~ /title=\"([^\"]*)\"/
      path = $1.to_s
      # action from "You ??? the ??? <...> ???....."
      act = td[1].to_s.gsub(/<[^>]*>/,"")
      # date from <td class="modified"> ???? </td>
      td[2].to_s =~ /class="modified">(.*)<\/td>/
      dat = $1.to_s

      if(dat=~/ago/)
        today = Time.now.strftime("%m/%d/%Y")
        eventlist << [act,today,path]
      else
        eventlist << [act,dat,path] unless(dat == ""||path == "")
      end
    }
    return eventlist
  end

  def get_all_events
#    date_str = Time.now.strftime("%Y-%m-%d")
    page = 0
    all_event = Array.new

    event_list = get_events_list(@TODAY, page)
    while( event_list != [] )
      all_event += event_list
      page += 1
      event_list = get_events_list(@TODAY, page)
    end

    return all_event
  end

  def set_csv_events
    event_list = get_all_events
    event_csv = ""
    event_list.each{|el|
      if( el[0] =~ /You[\s]([^\s]*)[\s](the[\s])?([^\s]*)[\s](.*)\./ )
        event_csv += ($1 + "," + $3 + "," + el[2] + "," + el[1].split.first + "\n")
      else
        puts el
      end
    }
    return event_csv
  end

end

class CSV_Parser

  def initialize
  end

end


db = Dropbox_Events.new

eventlist = db.set_csv_events

# - - - イベントをわける．
event_arr = Array.new
eventlist.each_line{|event|
  blankarr = event.split(",")
  if blankarr[1] == "file" ## file -> dir
    blankarr[2] =~ /(.*)\/([^\/]*)$/
    blankarr[2] = $1
    blankarr[2] = "/" if(blankarr[2]=="")
  end
  event_arr << blankarr if(blankarr[1] == "file"||blankarr[1] == "folder")
}
# event_arr = [change, type(file or directory), path_of_directory, date]

# - - - ディレクトリ，更新日時が何種類あるか
dir_names = Array.new
mod_dates = Array.new
event_arr.each{|event|
  dir_names << event[2]
  mod_dates << event[3]#.split.first
}

dir_names.uniq! # ディレクトリ種類
mod_dates.uniq!  # 日時種類

# - - - ディレクトリに通版割り振り
dir_num = 1
dirs = Array.new
dir_names.each{|dir|
  dirs << [dir, dir_num]
  dir_num += 1
}
dir_hash = Hash[dirs]

# - - - 変更日時ごとに変更ディレクトリ保持
mods = Array.new
mod_dates.each{|mod|
  mods << [mod, [] ]
}
mod_hash = Hash[mods]

# event_arr = [change, type(file or directory), path_of_directory, date]
event_arr.each{|event|
  mod_hash[ event[3] ] << dir_hash[ event[2] ]
}

event_array = Array.new
mod_hash.each{|mod|
  mod_to_s = ""

  dirs.each{|dir|
    if( mod[1].index(dir[1]) )
      mod_to_s += "| *"
    else
      mod_to_s += "|  "
    end
  }

  event_array << [mod[0], mod_to_s]
}

### number : directory name
puts ("-" * 50).to_s
dirs.each{|d|
  puts d[1].to_s.rjust(2) + ": " + d[0]
}
puts ("-" * 50).to_s

# - - - dir表示
print (" " * 10).to_s + "|"
dirs.each{|d|
  print (d[1].to_s.rjust(2) + "|")
}
puts ""

# - - - 変更表示
event_array.each{|event|
  print event[0].chomp.rjust(10) + event[1] + "\n"
}


exit



##### 開発の墓場 #####

    #Mechanize::Cookie.parse(@dropbox_url, cookie_str){|c| @agent.cookie_jar.add(@dropbox_url, c)}
=begin
    @login_page = @agent.get(@login_url)
    login_form = @login_page.forms.first
    login_form["login_email"] = "academy.kimura@gmail.com"
    login_form["login_password"] = "kimura-Y"
    redirect_page = @agent.submit( login_form )
=end

#    @agent.get(@events_url)
#    puts @agent.page.title
dropbox_login = "https://www.dropbox.com/login?cont=https%3A//www.dropbox.com/events"
login = []
login = open( dropbox_login ){|line|
  login << line.read
}
#|file| RSS::Parser.parse(file.read)}
puts login
exit

eventlist.each {|list|
  puts list.first.chomp + "(#{list.last})"
}
