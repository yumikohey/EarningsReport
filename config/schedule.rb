set :environment, "production"
set :output, {:error => "log/cron_error_log.log", :standard => "log/cron_log.log"}

every :day, :at => "11:00pm" do
  rake 'daily_option_chains'
end

every '5 6 15 * *' do
	rake 'history_quotes'
end
