name 'aws_sdb_plugin'
type 'plugin'
rs_ca_ver 20161221
short_description "Amazon Web Services - SimpleDB"
long_description "Version: 1.4"
package "plugins/rs_aws_sdb"
import "sys_log"
import "plugin_generics"

plugin "rs_aws_sdb" do
  endpoint do
    default_scheme "https"
    path "/"
    query do {
      #"SignatureVersion" =>"2",
      #"SignatureMethod" => "HmacSHA256",
      "Version" => "2009-04-15"
    } end
  end

  type "domain" do
    href_templates "/?Action=CreateDomain&DomainName={{//DomainName}}"
    end

    # Tushar Started Here
    action "createdomain" do
      verb "POST"
      path "/?Action=CreateDomain"
      type "string"

      field "domainname" do
        alias_for "DomainName"
        type "string"
      end
    end

    action "deletedomain" do
      verb "GET"
      path "/?Action=DeleteDomain"
      type "string"
    end


    action "domainmetadata" do
      verb "GET"
      path "/?Action=DomainMetadata"
      type "string"
    end


    action "getattributes" do
      verb "GET"
      path "/?Action=GETAttributes"
      type "string"

      field "item.name" do
        alias_for "ItemName"
        location "query"
      end
 
      field "domainname" do
        alias_for "DomainName"
        location "query"
        type "string"
      end
    end


    action "listdomains" do
      verb "GET"
      path "href?Action=ListDomains"

      field "maxnumberofdomains" do
       alias_for "MaxNumberOfDomains"
       location "query"
      end

    end

    action "putattributes" do
      verb "POST"
      path "/?Action=PutAttributes"
      type "string"
      field "attribute.1.name" do
        alias_for "Attribute.1.Name"
        location "query"
        type "string"
      end

      field "attribute.x.value" do
       alias_for "Attribute.1.Value"
       location "query"
       type "string"
      end 
 
      field "domainname" do
        alias_for "DomainName"
        location "query"
        type "string"
      end
    end
 
    action "select" do
      verb "GET"
      path "/?Action=Select"
      type "string"
    end
 
    ### Tushar Ended here
    provision 'provision_db_instance'
    
    delete    'delete_db_instance'
  end 

end

resource_pool "sdb" do
  plugin $rs_aws_sdb
  host "sdb.us-east-1.amazonaws.com"
  auth "key", type: "aws" do
    version     4
    service    'sdb'
    region     'us-east-1'
    access_key cred('AWS_ACCESS_KEY_ID')
    secret_key cred('AWS_SECRET_ACCESS_KEY')
  end
end

define provision_db_instance(@declaration) return @db_instance do
  sub on_error: plugin_generics.stop_debugging() do
    call plugin_generics.start_debugging()
    $object = to_object(@declaration)
    $fields = $object["fields"]
    if $fields["db_snapshot_identifier"] != null 
      @db_instance = rs_aws_sdb.domain.create($fields)
    else
      @db_instance = rs_aws_rds.db_instance.create($fields)
    end
    sub on_error: skip do
      sleep_until(@db_instance.DBInstanceStatus == "available")
    end 
    @db_instance = @db_instance.get()
    call plugin_generics.stop_debugging()
  end
end

define handle_retries($attempts) do
  if $attempts <= 6
    sleep(10*to_n($attempts))
    call sys_log.set_task_target(@@deployment)
    call sys_log.summary("error:"+$_error["type"] + ": " + $_error["message"])
    call sys_log.detail("error:"+$_error["type"] + ": " + $_error["message"])
    log_error($_error["type"] + ": " + $_error["message"])
    $_error_behavior = "retry"
  else
    raise $_errors
  end
end

define delete_db_instance(@db_instance) do
  $delete_count = 0
  sub on_error: handle_retries($delete_count) do
    $delete_count = $delete_count + 1
    call plugin_generics.start_debugging()
    rs_aws_sdb.domain.destroy(name: $domain_name)
    if @db_instance.DBInstanceStatus != "deleting"
      @db_instance.destroy({ "skip_final_snapshot": "true" })
    end
    call plugin_generics.stop_debugging()
  end 
end