require 'dotenv'
require 'pdf-reader'
require 'csv'
require 'json'
require 'httparty'
require 'open-uri'

# Load the environment variables
Dotenv.load

# Get the embeddings for a token
def get_embeddings(token)
    response = HTTParty.post('https://api.openai.com/v1/embeddings',{
        headers: {
            "Content-Type" => "application/json",
            "Authorization" =>"Bearer #{ENV['OPENAI_API_KEY']}"
        },
        body: {
            "model" => "text-embedding-ada-002",
            "input"=> token.strip
        }.to_json
    })
     embedding = JSON.parse(response.body)
    
    return embedding["data"][0]["embedding"]
end

# gets text from pdf
def get_text_from_pdf(pdf_path)
    text = ""
    reader = PDF::Reader.new(StringIO.new(pdf_path))
    reader.pages.each do |page|
        text << page.text
    end
    return text
end

#Convert the text from the pdf to tokens
def get_tokens_from_text(callback)
    puts "Enter Y if your pdf is from a url or N if it is from your local machine:"
    input = gets.chomp
    input.downcase

    unless input == "y" || input == "n"
        puts "Invalid input, please enter Y or N"
    end

    if input == "y"
        puts "Enter the url of the pdf you want to extract text from:"
        url = gets.chomp
        pdf_path = URI.open(url).read
    else
        puts "Enter the path to the pdf you want to extract text from:"
        pdf_path = gets.chomp 
    end
     
    text = callback.call(pdf_path)
    text.delete("\n")
    text.delete("\r")
    text.gsub(/\s+/, " ")
    tokens = text.split(/\s*\n{2,}/) # Split the text into tokens of substrings
    return tokens
end


#Create a csv file with the embeddings
def create_csv_file()
    token_array = get_tokens_from_text(method(:get_text_from_pdf))
    puts "Creating csv file, this may take a while..."
    CSV.open("embeddings.csv", 'w') do |csv|
        # Write the headers
        csv <<["index","token","embeddings"]
        # Write the rows of data
        token_array.each_with_index do |token, index|
            csv << [index, token.strip,get_embeddings(token)]#strip removes whitespace from the tokens
        end
    end
    puts "Created csv file"
end

csv_file = create_csv_file()
