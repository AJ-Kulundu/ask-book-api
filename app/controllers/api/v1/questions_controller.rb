require 'dotenv'
require 'cosine_similarity'

Dotenv.load

class Api::V1::QuestionsController < ApplicationController
    def index
       @question = Rails.cache.fetch("questions", expires_in: 1.hour) do
       Question.order("ask_count DESC").limit(5)
       end
       render json: @question
    end

    def create
        embeddings =  load_embeddings("embeddings.csv")
        question_string  = question_params[:question].strip #remove whitespaces
        if !(question_string.end_with?("?"))
            question_string = question_string + "?"
        end

        question_exist = Question.exists?(question: question_string)
        if question_exist
            question = Question.where(question: question_string).first
            question.increment!(:ask_count)
            render json: question
        else
            answer,context = answer_query_with_context(question_string, embeddings)
            question = Question.create(question: question_string, answer: answer,context: context)
            if question.save
                render json: question
            else
                render json: {error: question.errors}, status: :unprocessable_entity
            end
        end
    end

    private
    def question_params
        params.require(:question).permit(:question)
    end

    def get_embeddings(question)
        response = HTTParty.post('https://api.openai.com/v1/embeddings',{
            headers: {
                "Content-Type" => "application/json",
                "Authorization" =>"Bearer #{ENV['OPENAI_API_KEY']}"
            },
            body: {
                "model" => "text-embedding-ada-002",
                "input"=> question
            }.to_json
        })
         embedding = JSON.parse(response.body)
        
        return embedding["data"][0]["embedding"]
    end

    def load_embeddings(fname)
        csv_data =  CSV.read(fname, headers: true)
        document_embeddings = {}
        csv_data.each do |row|
            hash_key = [JSON.parse(row["index"]), row["token"]]
            document_embeddings[hash_key] = JSON.parse(row["embeddings"])
        end
        return document_embeddings
    end

    def vector_similarity(a, b)
        # Ensure embeddings are of the same length
        unless a.length == b.length
            raise "Embeddings are not of the same length"
        end

        return cosine_similarity(a, b)
    end

    def order_document_sections_by_similarity(question, context)
        question_embedding = get_embeddings(question)
        documents = []
        context.each do |key, value|
        documents <<[vector_similarity(question_embedding, value), key]
        end
        similar_documents = documents.sort{ |a,b| b[0] <=> a[0]}
        return similar_documents
    end

    def construct_prompt(question,embeddings)
       relevant_documents = order_document_sections_by_similarity(question, embeddings)
       context = []
       count = 0 
       relevant_documents.each do |document|
          if count < 3
          context << document[1][1]
          count += 1
          else
            break
          end
       end
       header = "Answer the following question based on the context provided and if the answer isn\'t provided within the context say \" I don\'t know\". Please keep your answers to 4 sentences maximum, and speak in complete sentences. Stopspeaking once your point is made. \n \n"
       prompt = header+ "Context: \n\n" + context.join(" ") + "\n\nQ: "+question+ "\n\n A: "
       return prompt, context.join(" ")
    end

    def answer_query_with_context(question,embeddings)
         prompt,context =  construct_prompt(question,embeddings);
         response = HTTParty.post('https://api.openai.com/v1/completions',{
            headers: {
                "Content-Type" => "application/json",
                "Authorization" =>"Bearer #{ENV['OPENAI_API_KEY']}"
            },
            body: {
                model:"text-davinci-003",
                prompt: prompt,
                max_tokens: 150,
                temperature: 0,

            }.to_json})

            data = JSON.parse(response.body)

            return data["choices"][0]["text"],context
    end

end
