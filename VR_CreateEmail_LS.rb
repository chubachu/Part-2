# encoding: UTF-8
require 'sequel'
require 'rubygems'
require './login.rb' 
require 'date'
require 'time'
require 'uri'
require 'csv'
require './emailvariables.rb' 
require './handle.rb' 

#SQL Server Connections

DB1 =   Sequel.ado(:conn_string => "Provider=SQLOLEDB;Data Source=mirr-www-sql;Initial Catalog=resourcecenter;Integrated Security=SSPI")

#Puts Event Schedule to an array of hashes
csv_data = CSV.open '\\\corp-fs1-was\Marketing\Market\Marketing_Operations\Direct_Marketing\Email Generator\TestSchedule.csv'   #-- ON shared drive, split up from master list
headers = csv_data.shift.map {|i| i.to_s}
string_data = csv_data.map {|row| row.map {|cell| cell.to_s} }
event_schedule = string_data.map {|row| Hash[*headers.zip(row).flatten]}

#Array of I2DBIA IDs
I2DBIAList = []
I2DBIARID = DB1[:res_resource].filter(:name => 'Introduction to Developing BI Applications').select(:resourceid)
I2DBIARID.each do |rid|
	I2DBIAList.push(rid[:resourceid].to_s)
end
#Array of Mobile IDs
MobileList = []
MobileRID = DB1[:res_resource].filter(:name => 'Introduction to Mobile BI').select(:resourceid)
MobileRID.each do |rid|
	MobileList.push(rid[:resourceid].to_s)
end
#Array of I2BI IDs
I2BIList = []
I2BIRID  = DB1[:res_resource].filter(:name => 'Introduction to Enterprise BI').or(:name => 'Introduction to Enteprise BI').select(:resourceid)
I2BIRID.each do |rid|
	I2BIList.push(rid[:resourceid].to_s)
end

first_send = []
resend_email = []

#Creates an Array of Hashes for the Events that need Emails.  Which email type is based on days until class date.
event_schedule.each do |event|
	begin
	#Make sure date is custom formatted to 'yyyy/mm/d'
	classdate = Date.parse(event["Class Date"])
	rescue ArgumentError
		puts "Reformat Excel Date to custom format 'yyyy/mm/d'"
		exit
	end

	days_to_class = (classdate - Date.today)
	if days_to_class >= 21 && days_to_class <= 28
			print "3 weeks until "
			print event["City"]
			print " adding to First Send...\n"
			first_send.push({
				:rid => event["RID"],
				:classdate => event["Class Date"]
			})
	elsif days_to_class >=7 && days_to_class <= 14
			print "1 week until "
			print event["City"]
			print " adding to Resend...\n"
			resend_email.push({
				:rid => event["RID"],
				:classdate => event["Class Date"]
			})
	end
end

#Removes nil spaces in the Array
resend_email.delete(nil)
first_send.delete(nil)

email_body = []
#Creates an Array of Hashes for each Email, the content depending on which class array the RID is found in.
event_schedule.each do |event|
	first_send.each do |first|
		refulr = ''
		subject = ''
		from_sender = ''
		reply_email = ''
		if first[:rid].index(event["RID"]) != nil
			if MobileList.index(first[:rid]) != nil
			#Adding the class RID to the template URL allows content to be dynamic.
			refurl = $Mobileurl + event["RID"].to_s
			subject = $MobileFirstSendSubject
			from_sender = $MobileFromSender
			reply_email = $MobileReplyEmail
			elsif 
			I2BIList.index(first[:rid]) !=  nil
			refurl =  $I2BIurl + event["RID"].to_s
			subject = $I2BIFirstSendSubject
			from_sender = $I2BIFromSender
			reply_email = $I2BIReplyEmail
			elsif
			I2DBIAList.index(first[:rid]) != nil
			refurl = $I2DBIAurl + event["RID"].to_s
			subject = $I2DBIAFirstSendSubject
			from_sender = $I2DBIAFromSender
			reply_email = $I2DBIAReplyEmail
		else
			print "Cannot match RID for #{event["RID"]}"
			exit
		end
		
		first_body = ''
		#Gets the HTML Content generated by the dynamic template.
		require 'ntlm/http'
		url = URI.parse(refurl)
		rell = Net::HTTP::Get.new(refurl)
		rell.ntlm_auth($handleuser, 'corp', $handlepass)
		res = Net::HTTP.start(url.host, url.port) {|http| http.request(rell)}
		first_body = res.body
		# Prevents https: breaks in VR
		first_body = first_body.gsub('href="https:', 'href="nr_https:')
		email_body.push({:city => event["City"], 
			:rid => event["RID"], 
			:classdate => event["Class Date"], 
			:body => first_body,
			:from => from_sender,
			:support => reply_email,
			:subject => subject,
			:email_name => "",
			})
		end
	end

	resend_email.each do |resend|
		if resend[:rid].index(event["RID"]) != nil
			mainurl = ''
			textbody = ''
			resendsubject = ''
			from_sender = ''
			reply_email = ''
		if MobileList.index(resend[:rid]) != nil
			mainurl = $MobileResendurl + event["RID"]
			textbody = $MobileText
			resendsubject = $MobileResendSubjectBonnie
			from_sender = $MobileResendBonnieFromSender
			reply_email = $MobileREsendBonnieReplyEmail

		elsif I2BIList.index(resend[:rid]) != nil
			mainurl = $I2BIResendurl + event["RID"]
			textbody = $I2BIText
			resendsubject = $I2BIResendSubjectBonnie
			from_sender = $I2BIResendBonnieFromSender
			reply_email = $I2BIResendBonnieReplyEmail

		elsif
			I2DBIAList.index(resend[:rid]) != nil
			mainurl =  $I2DBResendurl + event["RID"]
			textbody = $I2DBText
			resendsubject = $I2DBIAResendSubjectBonnie
			from_sender = $I2DBIAResendBonnieFromSender
			reply_email = $I2DBIAIResendBonnieReplyEmail
		end
		
	require 'ntlm/http'
	resend_body = ''
	url = URI.parse(mainurl)
	rell = Net::HTTP::Get.new(mainurl)
	rell.ntlm_auth($handleuser, 'corp', $handlepass)
	res = Net::HTTP.start(url.host, url.port) {|http| http.request(rell)}
	resend_body = res.body
	resend_body = resend_body.gsub('href="https:', 'href="nr_https:')

	email_body.push({:city => event["City"], 
		:rid => event["RID"], 
		:classdate => event["Class Date"], 
		:body => resend_body,
		:from => from_sender,
		:support => reply_email,
		:subject => resendsubject,
		:email_name => "Bonnie",
	})
	end
end
end

email_body.delete(nil)

email_details = []
alphabet = ('A'...'Z').to_a
#Creates split test versions of Email where '&:' is found in the subject line
	email_body.each do |splitting|
		if splitting[:subject].match("&: ")
		splitting[:subject].split("&: ").each_with_index do |sub, pos|
			email_details.push({:city => splitting[:city], 
					:rid => splitting[:rid], 
					:classdate => splitting[:classdate], 
					:body => splitting[:body],
					:from => splitting[:from],
					:support => splitting[:support],
					:subject => sub,
					:email_name => alphabet[pos]
			})

			end
		else
		email_details.push({:city => splitting[:city], 
					:rid => splitting[:rid], 
					:classdate => splitting[:classdate], 
					:body => splitting[:body],
					:from => splitting[:from],
					:support => splitting[:support],
					:subject => splitting[:subject],
					:email_name => splitting[:email_name]
				})
		end
	end

Email_log = []

email_details.delete(nil)

email_details.each do |email|
	#Determines which class type each Email is.
		if I2BIList.index(email[:rid]) != nil
			listtype = "I2BI "
		elsif MobileList.index(email[:rid]) != nil
			listtype = "I2M "
		elsif I2DBIAList.index(email[:rid]) !=nil
			listtype = "I2DB "
		end
	if email[:subject] == ''
		print "NO Subject??"
		exit
	end
	#Logic for generating each Email's Name in VR
	if email[:email_name].length == 1
		if email[:city].match(",")
			email[:email_name] = listtype +email[:city][0...email[:city].index(",")]+" "+Date.parse(email[:classdate]).strftime("%m.%d.%Y")+" "+email[:email_name]
		else
			email[:email_name] = listtype +email[:city].strip+" "+Date.parse(email[:classdate]).strftime("%m.%d.%Y")+" "+email[:email_name]
		end
	end
	if email[:email_name] == ''
		if email[:city].match(",")
			email[:email_name] = listtype +email[:city][0...email[:city].index(",")]+" "+Date.parse(email[:classdate]).strftime("%m.%d.%Y")
		else
			email[:email_name] = listtype +email[:city].strip+" "+Date.parse(email[:classdate]).strftime("%m.%d.%Y")
		end
	end
	if email[:email_name] == 'Bonnie'
		if email[:city].match(",")
			email[:email_name] = listtype +email[:city][0...email[:city].index(",")]+" "+Date.parse(email[:classdate]).strftime("%m.%d.%Y")+" Resend"
		else
			email[:email_name] = listtype +email[:city].strip+" "+Date.parse(email[:classdate]).strftime("%m.%d.%Y")+ " Resend"
		end
	end
	if email[:email_name] == 'Peter'
		if email[:city].match(",")
			email[:email_name] = listtype +email[:city][0...email[:city].index(",")]+" "+Date.parse(email[:classdate]).strftime("%m.%d.%Y")+" Resend"
		else
			email[:email_name] = listtype +email[:city].strip+" "+Date.parse(email[:classdate]).strftime("%m.%d.%Y")+ " Resend"
		end
	end
	#If no Support or From address is specified...
	if email[:support] == ''
		email[:support] = 'info@microstrategy.com'
	end
	if email[:from] == '' 
		email[:from] = 'MicroStrategy'
	end
	#Creates Subject Line dependent on formatting and other details
	if email[:city].match(",")
		cityrep = email[:city][0...email[:city].index(",")]
		email[:subject] = email[:subject].gsub("!City", cityrep)
	else
		cityrep = email[:city].strip
		email[:subject] = email[:subject].gsub("!City", cityrep)
	end


	if email[:subject].match("!DayOfWeek")
		email[:subject] = email[:subject].gsub("!DayOfWeek", Date.parse(email[:classdate]).strftime("%A"))
	end
	
	if email[:subject].match("!Date")
		email[:subject] = email[:subject].gsub("!Date", Date.parse(email[:classdate]).strftime("%m/%d"))
	end

	#VR API call to create email
	require 'soap/wsdlDriver'  
	wsdl = 'https://api.verticalresponse.com/partner-wsdl/1.0/VRAPI.wsdl'  
	vr = SOAP::WSDLDriverFactory.new(wsdl).create_rpc_driver

	sid = vr.login(
      	     	{
     	          	'username' => $username,
     	          	'password' => $pass,
  	             	'session_duration_minutes' => 120})	
  classdate = "Class Date"

  vrcid = vr.createEmail({
  		'session_id' => sid,
  		'email' => {
  					#VR has a 40 character limit on Email Names
    	 	   'name' => email[:email_name][0..39],
    	 	   'email_type' => 'freeform',
    	 	   'from_label' => email[:from],
    	 	   'reply_to_email' => email[:support],
    	 	   'send_friend' => true,
    	 	   'subject' => email[:subject],
    	 	   'freeform_html' => email[:body],
    	 	   'unsub_message' => 'You requested these emails, if you would like to be removed from the list?  ',
    	},
  })

  Email_log.push({:vr_cid => vrcid,
  		:email_name => email[:email_name],
  		:rid => email[:rid],
  		:city => email[:city]
	})

end

DB2 =   Sequel.ado(:conn_string => "Provider=SQLOLEDB;Data Source=test-wwwdb-sql;Initial Catalog=marketing_raymond;Integrated Security=SSPI")

if DB2.table_exists?(:Email_Log_List)
	print "Adding to LogList...\n"
else
	DB2.create_table! :Email_Log_List do
		String :email_name
		Integer :listid
		String :vr_cid
		Integer :resourceid
		DateTime :create_date
	end
end

Distro_List_Items = []
#Creates a Log of what Emails were created
Email_log.each do |created_email|
	DB2[:Email_Log_List].filter(:email_name => created_email[:email_name]).delete
	DB2[:Email_Log_List].insert(:email_name => created_email[:email_name], :listid => 0, :vr_cid => created_email[:vr_cid], :create_date => Date.today, :resourceid => created_email[:rid])
	#Populates ReferenceTbl.csv for distribution list creation.
	if created_email[:email_name].match(/\s\w\z/i)
		Distro_List_Items.push ({:email_name => created_email[:email_name][0..-3], :split => "yes", :city => created_email[:city]})
	else
		Distro_List_Items.push ({:email_name => created_email[:email_name], :split => "null", :city => created_email[:city]})
	end
end


CSV.open("ReferenceTbl.csv", "wb") do |csv|
	csv << ["Tablename", "LU_City", "LU_State", "Radius", "MSA", "State", "Zipcode", "Exstate", "Onlystate", "Exmsa", "Split", "Recent", "Click", "Exclude", "Customer", "Country", "Excountry", "ExRID", "LOB"]
	Distro_List_Items.uniq.each do |row|
		if row[:city].match(",")
			csv << [row[:email_name], row[:city][0...row[:city].index(",")], row[:city][row[:city].index(",")+2...row[:city].length], "null", "null", "null", "null", "null", "null", "null", row[:split], "null", "null", "null", "null", "1, 3", "null", "null", "null"]
		else
			csv << [row[:email_name], row[:city],"null", "null", "null", "null", "null", "null", "null", "null", row[:split], "null", "null", "null", "null", "1, 3", "null", "null", "null"]
		end
	end
end

print "Creating Emails and updating LogList!!"


