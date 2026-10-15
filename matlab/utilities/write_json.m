function write_json(path,data)
f=fopen(path,'w');assert(f>=0);cl=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(data,'PrettyPrint',true));
end

