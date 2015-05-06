module EreportsHelper

	def self.get_earning_report_dates(stock_symbol, stock_id, each_qrt, each_year)
		url = "http://www.estimize.com/#{stock_symbol}/fq#{each_qrt}-#{each_year}#chart=historical"
		begin 
			page = Nokogiri::HTML(open(url))
		rescue
			p "no reports for #{each_year} #{each_qrt}"
		else
			page.search('.date').map do |element|
				temp = (element.inner_text[0..-5]).split('/')
				date_str = (temp[1] +'/'+ temp[0] +'/20'+ temp[2]).to_s
				earning_report = Ereport.create(symbol:stock_symbol, date:date_str, stock_id:stock_id)
				p earning_report.stock_id
			end	
		end
	end

	def self.yahoo_url(stock_symbol, date_one, date_two, month_one, month_two, year)
		"http://finance.yahoo.com/q/hp?s=#{stock_symbol}&a=#{month_one}&b=#{date_one}&c=#{year}&d=#{month_two}&e=#{date_two}&f=#{year}&g=d"
	end

	def self.earning_report_dates_data(stock_symbol, earning)
		the_day = earning.date
		if the_day <= Date.today
			formatted_date = the_day.strftime("%m/%d/%Y").to_s.split("/")
			month = formatted_date[0].to_i
			date = formatted_date[1].to_i
			year = formatted_date[2].to_i
			special_date = the_day.prev_month.end_of_month.strftime('%Y/%m/%d').to_s.split('/')
			if (the_day.month == the_day.next_day.month) && (!the_day.next_day.saturday?) && (the_day.month == the_day.prev_day.month)
				url = yahoo_url(stock_symbol, date-1, date+1, month-1, month-1, year)
			elsif (the_day.month != the_day.prev_day.month) && (!the_day.next_day.saturday?)
				url = yahoo_url(stock_symbol, special_date[2].to_i, date+1, month-2, month-1, year)
			elsif (the_day.month != the_day.prev_day.month) && (the_day.next_day.saturday?)	
				url =	yahoo_url(stock_symbol, special_date[2].to_i, date+3, month-2, month-1, year)			
			elsif (the_day.month != the_day.next_day.month) && (!the_day.next_day.saturday?) && (the_day.month == the_day.prev_day.month)
				url = yahoo_url(stock_symbol, date-1,1, month-1, month, year)
			elsif (the_day.month != the_day.next_day.month) && (the_day.next_day.saturday?) && (the_day.month == the_day.prev_day.month)
				url = yahoo_url(stock_symbol, date-1,3, month-1, month, year)
			elsif (the_day.month == the_day.next_day.month) && (the_day.next_day.saturday?) && (the_day.month == the_day.prev_day.month)
				url = yahoo_url(stock_symbol, date-1, date+3, month-1, month, year)
			end
			p "#{the_day} #{url}"
			page = Nokogiri::HTML(open(url))
			page.search('.yfnc_datamodoutline1').map do |element|
				# @html.push(element.inner_html)
				pricing_array = []
				price_before_er = PriceBeforeEr.create(ereport_id:earning.id)
				price_on_er = PriceOnEr.create(ereport_id:earning.id)
				price_after_er = PriceAfterEr.create(ereport_id:earning.id)
				array_of_quotes = element.css('.yfnc_tabledata1')
				array_of_quotes.each do |quote|
					p html_str = quote.inner_text
					if  html_str.match('[a-zA-Z]{3}\s\d{1,2}\,\s\d{4}')
						er_date = Date.parse(html_str)
						if er_date < the_day
							price_before_er.price_date = er_date
							price_before_er.save
						elsif er_date > the_day
							price_after_er.price_date = er_date
							price_after_er.save
						else
							price_on_er.price_date = er_date
							price_on_er.save
						end
					elsif html_str.match('\d*\.\d*')
						price = html_str.to_f
						if price_before_er.price_date && (price_before_er.quote.length != 5)
							price_before_er.quote.push(price)
							price_before_er.save
						elsif price_after_er.price_date && (price_after_er.quote.length != 5)
							price_after_er.quote.push(price)
							price_after_er.save
						elsif ( price_on_er.quote.length != 5)
							price_on_er.quote.push(price)
							price_on_er.save
						end

					else
						stock_volume = html_str.tr(",","").to_i
						p "this volume"
						if price_before_er.price_date
							price_before_er.volume = stock_volume
							price_before_er.save
						elsif price_on_er.price_date
							price_on_er.volume = stock_volume
							price_on_er.save
						elsif price_after_er.price_date
							price_after_er.volume = stock_volume
							price_after_er.save
						end
					end

				end
			end
		else
			p the_day
		end

	end
end
