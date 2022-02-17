.PHONY: post
post: ## medium に post します (make post PATH=article/20220217-0)
	gh workflow run post-medium -F article_path=$(PATH)
