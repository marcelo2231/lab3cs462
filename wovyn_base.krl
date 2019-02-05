ruleset io.picolabs.wovyn_base {
 meta {
    shares __testing
    use module io.picolabs.lesson_keys
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
  }
  global {
     __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "post", "type": "test",
                              "attrs": [ "temp", "baro" ] } ] }
    temperature_threshold = 70
    to = "+18018089633"
    from = "+13852090219"
  }
  
  
  rule process_heartbeat {
    select when wovyn heartbeat
    pre{
      genericThingIsPresent = (event:attrs{"genericThing"} != null)
      temperature = (genericThingIsPresent) => event:attrs{"genericThing"}{"data"}{"temperature"}[0]{"temperatureF"} | null
      timestamp = time:now()
    }
    if genericThingIsPresent then
      send_directive("Result", {"temperature": temperature, "timestamp": timestamp})
    
    fired{
      raise wovyn event "new_temperature_reading"
        attributes { "temperature": temperature, "timestamp": timestamp }
    }else{
      
    }
  }
  
  
  rule find_high_temps{
    select when wovyn new_temperature_reading
    pre{
      temperature = event:attr("temperature")
      temperature_violation = event:attr("temperature") > temperature_threshold
    }
    if temperature_violation then
      send_directive("temperature_violation", {"temperature":temperature,
                                               "temperature_threshold": temperature_threshold,
                                               "temperature_violation": temperature_violation})

    fired{
        raise wovyn event "threshold_violation"
          attributes { "temperature":  event:attr("temperature"), "timestamp":  event:attr("timestamp") }
    }else{
      
    }
  }
  
  
  rule threshold_notification{
    select when wovyn threshold_violation
    twilio:send_sms(to,
                    from,
                    "Temperature violation notification! Temperature was reported to be " + event:attr("temperature") + "°F." +
                    "The temperature threadshold is " + temperature_threshold + "°F. And this occured on the following time: " +
                    event:attr("timestamp") + ".")
  }
}
