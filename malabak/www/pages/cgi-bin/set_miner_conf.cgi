#!/bin/sh

function cgi_get_POST_vars()
{
    [ "${CONTENT_TYPE}" != "application/x-www-form-urlencoded" ] && \
    echo "Warning: you should probably use MIME type "\
         "application/x-www-form-urlencoded!" 1>&2
    [ -z "$QUERY_STRING_POST" \
      -a "$REQUEST_METHOD" = "POST" -a ! -z "$CONTENT_LENGTH" ] && \
    read -n $CONTENT_LENGTH QUERY_STRING_POST
    return
}

function update_config_file()
{
    config_file="/config/cgminer.conf"
    echo "{"                                                            > $config_file
    echo "\"pools\" : ["                                                >> $config_file
    echo "{"                                                            >> $config_file
    echo "\"url\" : \"$ant_pool1url\","                                 >> $config_file
    echo "\"user\" : \"$ant_pool1user\","                               >> $config_file
    echo "\"pass\" : \"$ant_pool1pw\""                                  >> $config_file
    echo "},"                                                           >> $config_file
    echo "{"                                                            >> $config_file
    echo "\"url\" : \"$ant_pool2url\","                                 >> $config_file
    echo "\"user\" : \"$ant_pool2user\","                               >> $config_file
    echo "\"pass\" : \"$ant_pool2pw\""                                  >> $config_file
    echo "},"                                                           >> $config_file
    echo "{"                                                            >> $config_file
    echo "\"url\" : \"$ant_pool3url\","                                 >> $config_file
    echo "\"user\" : \"$ant_pool3user\","                               >> $config_file
    echo "\"pass\" : \"$ant_pool3pw\""                                  >> $config_file
    echo "}"                                                            >> $config_file
    echo "]"                                                            >> $config_file
    echo ","                                                            >> $config_file
    echo "\"algo\" : \"$ant_algo\","                                    >> $config_file
    # echo "\"api-listen\" : true,"                                       >> $config_file
    # echo "\"api-network\" : true,"                                      >> $config_file
    # echo "\"api-groups\" : \"A:stats:pools:devs:summary:version\","     >> $config_file
    # echo "\"api-allow\" : \"A:0/0,W:*\","                               >> $config_file
    echo "\"bitmain-fan-ctrl\" : ${ant_fan_customize_value:-"false"},"  >> $config_file
    echo "\"bitmain-fan-pwm\" : \"$ant_fan_customize_switch\","         >> $config_file
    # echo "\"bitmain-use-vil\" : true,"                                  >> $config_file
    echo "\"bitmain-freq\" : \"$ant_freq\","                            >> $config_file
    echo "\"bitmain-voltage\" : \"$ant_voltage\","                      >> $config_file
    # echo "\"bitmain-ccdelay\" : \"$ant_ccdelay\","                      >> $config_file
    # echo "\"bitmain-pwth\" : \"$ant_pwth\","                            >> $config_file
    echo "\"bitmain-work-mode\" : \"$ant_miner_mode\","                 >> $config_file
    echo "\"bitmain-freq-level\" : \"$ant_freq_level\""                 >> $config_file
    #echo "\"miner-mode\" : \"$ant_work_mode\","                        >> $config_file
    #echo "\"freq-level\" : \"$ant_freq_level\""                        >> $config_file
    echo "}"                                                            >> $config_file
}

function parse_configs()
{
    echo $1 | jq -r $2
}

function old_configs()
{
    cat /config/cgminer.conf | jq -r $1
}

function factory_configs()
{
    cat /etc/cgminer.conf.factory | jq -r $1
}
reload=false
cgi_get_POST_vars

#echo $QUERY_STRING_POST > /tmp/aaa
#QUERY_STRING_POST=`cat /tmp/aaa`

echo $QUERY_STRING_POST | jq > /dev/null

if [[ $? -eq 0 ]]&&[[ ! "$QUERY_STRING_POST"x == ""x ]]; then
	QUERY_STRING_POST=`echo $QUERY_STRING_POST | jq -c`
    ret=`parse_configs $QUERY_STRING_POST ".pools[0].url"`
    if [ "$ret"x == "null"x ];then
        ant_pool1url=`old_configs ".pools[0].url"`
    else
        ant_pool1url=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST ".pools[0].user"`
    if [ "$ret"x == "null"x ];then
        ant_pool1user=`old_configs ".pools[0].user"`
    else
        ant_pool1user=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST ".pools[0].pass"`
    if [ "$ret"x == "null"x ];then
        ant_pool1pw=`old_configs ".pools[0].pass"`
    else
        ant_pool1pw=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST ".pools[1].url"`
    if [ "$ret"x == "null"x ];then
        ant_pool2url=`old_configs ".pools[1].url"`
    else
        ant_pool2url=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST ".pools[1].user"`
    if [ "$ret"x == "null"x ];then
        ant_pool2user=`old_configs ".pools[1].user"`
    else
        ant_pool2user=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST ".pools[1].pass"`
    if [ "$ret"x == "null"x ];then
        ant_pool2pw=`old_configs ".pools[1].pass"`
    else
        ant_pool2pw=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST ".pools[2].url"`
    if [ "$ret"x == "null"x ];then
        ant_pool3url=`old_configs ".pools[2].url"`
    else
        ant_pool3url=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST ".pools[2].user"`
    if [ "$ret"x == "null"x ];then
        ant_pool3user=`old_configs ".pools[2].user"`
    else
        ant_pool3user=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST ".pools[2].pass"`
    if [ "$ret"x == "null"x ];then
        ant_pool3pw=`old_configs ".pools[2].pass"`
    else
        ant_pool3pw=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST '."algo"'`
    if [ "$ret"x == "null"x ];then
        ant_algo=`factory_configs '."algo"'`
    else
        ant_algo=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST '."bitmain-fan-ctrl"'`
    if [ "$ret"x == "null"x ];then
        ant_fan_customize_value=`old_configs '."bitmain-fan-ctrl"'`
    else
        ant_fan_customize_value=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST '."bitmain-fan-pwm"'`
    if [ "$ret"x == "null"x ];then
        ant_fan_customize_switch=`old_configs '."bitmain-fan-pwm"'`
    else
        ant_fan_customize_switch=$ret
    fi
    ret=`parse_configs $QUERY_STRING_POST '."miner-mode"'`
    if [[ "$ret"x == "null"x ]]||([[ $ret -ne 0 ]]&&[[ $ret -ne 1 ]]);then
        ant_miner_mode=`old_configs '."bitmain-work-mode"'`
        reload=true
    else
        old_ant_miner_mode=`old_configs '."bitmain-work-mode"'`
        ant_miner_mode=$ret
        if [ $old_ant_miner_mode == $ret ];then
            reload=true
        fi
    fi
    ret=`parse_configs $QUERY_STRING_POST '."freq-level"'`
    if [ "$ret"x == "null"x ];then
        ant_freq_level=`old_configs '."bitmain-freq-level"'`
    else
        ant_freq_level=$ret
    fi
    # ant_ccdelay=`old_configs '."bitmain-ccdelay"'`
    # ant_pwth=`old_configs '."bitmain-pwth"'`
    ant_freq=`old_configs '."bitmain-freq"'`
    ant_voltage=`old_configs '."bitmain-voltage"'`
#   ret=`parse_configs $QUERY_STRING_POST '."bitmain-freq"'`
#   if [ "$ret"x == "null"x ];then
#       ant_freq=`old_configs '."bitmain-freq"'`
#   else
#       ant_freq=$ret
#   fi
#   ret=`parse_configs $QUERY_STRING_POST '."bitmain-voltage"'`
#   if [ "$ret"x == "null"x ];then
#       ant_voltage=`old_configs '."bitmain-voltage"'`
#   else
#       ant_voltage=$ret
#   fi
#   ret=`parse_configs $QUERY_STRING_POST '."bitmain-ccdelay"'`
#   if [ "$ret"x == "null"x ];then
#       ant_ccdelay=`old_configs '."bitmain-ccdelay"'`
#   else
#       ant_ccdelay=$ret
#   fi
#   ret=`parse_configs $QUERY_STRING_POST '."bitmain-pwth"'`
#   if [ "$ret"x == "null"x ];then
#       ant_pwth=`old_configs '."bitmain-pwth"'`
#   else
#       ant_pwth=$ret
#   fi

    update_config_file
    sync
    sleep 1s
    
    if [ $reload == true ];then
        cgminer-api {\"command\":\"reload\",\"new_api\":true} > /dev/null &
    else
        sudo /etc/init.d/S70cgminer restart > /dev/null &
    fi

    echo "{\"stats\":\"success\",\"code\":\"M000\",\"msg\":\"OK!\"}"
else
    echo "{\"stats\":\"error\",\"code\":\"M001\",\"msg\":\"Illegal request!\"}"
fi
