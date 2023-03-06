require "csv"
require "dotenv"
require "httparty"
require "json"

Dotenv.load

def get_tokens(file_path)
  csv_data = []
  data  = CSV.read(file_path,headers:false).drop(1)
  data.each do |row|
    csv_data << row[0]
  end
  return csv_data
end

def get_embeddings(text)
response = HTTParty.post('https://api.openai.com/v1/embeddings',{
    headers: {
        "Content-Type" => "application/json",
        "Authorization" =>"Bearer #{ENV['OPENAI_API_KEY']}"
    },
    body: {
        "model" => "text-embedding-ada-002",
        "input"=> text
    }.to_json
})
 embedding = JSON.parse(response.body)

return embedding["data"][0]["embedding"]
end

def create_csv_file()
    tokens = get_tokens("microsoft-earnings.csv")
    puts "Creating csv file, this may take a while..."
    CSV.open("embeddings.csv", "wb") do |csv|
        csv<<["index","token","embeddings"]
        tokens.each_with_index do |token, index|
            csv<<[index,token,get_embeddings(token)]
        end
    end
    puts "CSV file created"
end


create_csv_file()