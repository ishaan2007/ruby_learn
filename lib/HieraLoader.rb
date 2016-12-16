require "HieraLoader/version"
require 'yaml'

module HieraLoader
  # Your code goes here...
  class DctPuppetHiera

    attr_reader :yamllist,:foundkeys

    def initialize(yamllist=[])
      @yamllist = yamllist
      @foundkeys = {}
    end

    def mergeYamlFiles
      mergedyaml={}
      yamllist.each do |yamlfile|
        next unless File.exist? yamlfile
        data = YAML.load_file("#{yamlfile}")
        mergedyaml = mergedyaml.merge! data
      end
      interpolate(mergedyaml)
      return mergedyaml
    end

    def flattenYamlArrays(yamldata)
      newdata = {}
      yamldata.each do |key,value|
        if value.is_a?(Array)
          value.each do |v|
            if v.is_a?Hash or v.is_a?Array
              newdata.merge!flattenYamlArrays(v)
            end
          end
        else
          newdata[key] = value
        end
      end
      return newdata
    end
    private :flattenYamlArrays

    def interpolate(mergedyaml={})
      mergedyaml.each do |key,value|

        if value.is_a?Array
          index = -1
          value.each do |value2|
            index += 1
            if value2.is_a? Hash
              value2.each do |key3,value3|
                interpolate_value(mergedyaml,key3,value3,[],value2)
                interpolate_key(mergedyaml,key3,value3,[],value2)
              end
            elsif value2.is_a? String
              puts "running interpolate for #{index} and #{value2}"
              interpolate_value(mergedyaml,index,value2,[],value)
              interpolate_key(mergedyaml,index,value2,[],value)
            end

          end
        end
        interpolate_value(mergedyaml,key,value,[])
      end
    end
    private :interpolate

    def interpolate_value(mergedyaml,key,value,searchingfor=[],innermap={})
      return if not value.is_a? String
      raise ("possible loop in hiera") if searchingfor.include?(key)
      if(match = value.match (/\%\{hiera\(\'([^\']*)\'\)\}/))
        newvalue = value.sub(match[0],mergedyaml[match[1]])
        searchingfor.push(match[1])
        puts "in array #{key}"
        if innermap.is_a?Array
          innermap[key] = newvalue
        elsif mergedyaml.has_key? key
          mergedyaml[key] = newvalue
        elsif innermap.is_a? Hash

          innermap[key] = newvalue
        end
        interpolate_value(mergedyaml,key,newvalue,searchingfor,innermap)
      end
      return value
    end

    def interpolate_key(mergedyaml,key,value,searchingfor=[],innermap={})
      return if not key.is_a? String
      raise ("possible loop in hiera") if searchingfor.include?(key)
      if(match = key.match (/\%\{hiera\(\'([^\']*)\'\)\}/))
        newvalue = key.sub(match[0],mergedyaml[match[1]])
        searchingfor.push(match[1])
        puts "in array #{key}"
        if innermap.is_a?Array
          innermap.delete_at(key)
          innermap.insert(key,newvalue)
        elsif mergedyaml.has_key? key
          mergedyaml[newvalue] = mergedyaml.delete key
        elsif innermap.is_a? Hash
          innermap[newvalue] = innermap.delete key
        end
        interpolate_key(mergedyaml,key,newvalue,searchingfor,innermap)
      end
      return key
    end

    private :interpolate_value, :interpolate_key
  end
end
