require "emr_ohsp_interface/version"

module EmrOhspInterface
  module EmrOhspInterfaceService
    class << self
      require 'csv'
      require 'rest-client'
      def settings
        file = File.read(Rails.root.join("db","idsr_metadata","idsr_ohsp_settings.json"))
        config = JSON.parse(file)
      end

      def get_ohsp_facility_id
        file = File.open(Rails.root.join("db","idsr_metadata","emr_ohsp_facility_map.csv"))
        data = CSV.parse(file,headers: true)
        emr_facility_id = Location.current_health_center.id
        facility = data.select{|row| row["EMR_Facility_ID"].to_i == emr_facility_id}
        ohsp_id = facility[0]["OrgUnit ID"]
      end

      def get_ohsp_de_ids(de,type)
        #this method returns an array ohsp report line ids
        result = []
        #["waoQ016uOz1", "r1AT49VBKqg", "FPN4D0s6K3m", "zE8k2BtValu"]
        #  ds,              de_id     ,  <5yrs       ,  >=5yrs
        if type == "weekly"
        file = File.open(Rails.root.join("db","idsr_metadata","idsr_weekly_ohsp_ids.csv"))
        else
        file = File.open(Rails.root.join("db","idsr_metadata","idsr_monthly_ohsp_ids.csv"))
        end
        data = CSV.parse(file,headers: true)
        row = data.select{|row| row["Data Element Name"].strip.downcase.eql?(de.downcase)}
        ohsp_ds_id = row[0]["Data Set ID"]
        result << ohsp_ds_id
        ohsp_de_id = row[0]["UID"]
        result << ohsp_de_id
        option1 = row[0]["<5Yrs"]
        result << option1
        option2 = row[0][">=5Yrs"]
        result << option2

        return result
      end

      def get_data_set_id(type)
        if type == "weekly"
          file = File.open(Rails.root.join("db","idsr_metadata","idsr_weekly_ohsp_ids.csv"))
        else
          file = File.open(Rails.root.join("db","idsr_metadata","idsr_monthly_ohsp_ids.csv"))
        end
        data = CSV.parse(file,headers: true)
        data_set_id = data.first["Data Set ID"]
      end

      def generate_weekly_idsr_report()

        diag_map = settings["weekly_idsr_map"]

        epi_week = weeks_generator.last.first.strip
        start_date = weeks_generator.last.last.split("to")[0].strip
        end_date = weeks_generator.last.last.split("to")[1].strip

        #pull the data
        type = EncounterType.find_by_name 'Outpatient diagnosis'
        collection = {}

        diag_map.each do |key,value|
          options = {"<5yrs"=>nil,">=5yrs"=>nil}
          concept_ids = ConceptName.where(name: value).collect{|cn| cn.concept_id}

          data = Encounter.where('encounter_datetime BETWEEN ? AND ?
          AND encounter_type = ? AND value_coded IN (?)
          AND concept_id IN(6543, 6542)',
          start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
          end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
          joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
          INNER JOIN person p ON p.person_id = encounter.patient_id').\
          select('encounter.encounter_type, obs.value_coded, p.*')

          #under_five
          under_five = data.select{|record| calculate_age(record["birthdate"]) < 5}.\
                      collect{|record| record.person_id}
          options["<5yrs"] = under_five
          #above 5 years
          over_five = data.select{|record| calculate_age(record["birthdate"]) >=5 }.\
                      collect{|record| record.person_id}

          options[">=5yrs"] =  over_five

          collection[key] = options
        end

        response = send_data(collection,"weekly")
      end

      def generate_monthly_idsr_report()
      end

      # helper menthod
      def months_generator
          months = Hash.new
          count = 1
          curr_date = Date.today
          while count < 13 do
              curr_date = curr_date - 1.month
              months[curr_date.strftime("%Y%m")] = [curr_date.strftime("%B-%Y"),\
                                        (curr_date.beginning_of_month.to_s+" to " + curr_date.end_of_month.to_s)]
              count +=  1
          end
          return months.to_a
      end

      # helper menthod
      def weeks_generator

        weeks = Hash.new
        first_day = ((Date.today.year.to_s)+"-01-01").to_date
        wk_of_first_day = first_day.cweek

        if wk_of_first_day > 1
          wk = first_day.prev_year.year.to_s+"W"+wk_of_first_day.to_s
          dates = "#{(first_day-first_day.wday+1).to_s} to #{((first_day-first_day.wday+1)+6).to_s}"
          weeks[wk] = dates
        end

        #get the firt monday of the year
        while !first_day.monday? do
          first_day = first_day+1
        end
        first_monday = first_day
        #generate week numbers and date ranges

        while first_monday <= Date.today do
            wk = (first_monday.year).to_s+"W"+(first_monday.cweek).to_s
            dates =  "#{first_monday.to_s} to #{(first_monday+6).to_s}"
            #add to the hash
            weeks[wk] = dates
            #step by week
            first_monday += 7
        end
      #remove the last week
      this_wk = (Date.today.year).to_s+"W"+(Date.today.cweek).to_s
      weeks = weeks.delete_if{|key,value| key==this_wk}

      return weeks.to_a
      end

      #Age calculator
      def calculate_age(dob)
        age = ((Date.today-dob.to_date).to_i)/365 rescue 0
      end

      def send_data(data,type)
        # method used to post data to the server
        #prepare payload here
        conn = settings["headers"]
        payload = {
          "dataSet" =>get_data_set_id(type),
          "period"=>(type.eql?("weekly") ? weeks_generator.last[0] : months_generator.first[0]),
          "orgUnit"=> get_ohsp_facility_id,
          "dataValues"=> []
        }

        data.each do |key,value|
            option1 =  {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                        "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[2],
                        "value"=>value["<5yrs"].size }

            option2 = {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                        "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[3],
                        "value"=>value[">=5yrs"].size}

        #fill data values array
          payload["dataValues"] << option1
          payload["dataValues"] << option2
        end

        puts "now sending these values: #{payload.to_s}"
        url = "#{conn["url"]}/api/dataValueSets"
        puts url
        send = RestClient::Request.execute(method: :post,
                                            url: url,
                                            headers:{'Content-Type'=> 'application/json'},
                                            payload: payload.to_json,
                                            #headers: {accept: :json},
                                            user: conn["user"],
                                            password: conn["pass"])

        puts send
      end

    end
  end


end
