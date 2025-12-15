package postgres

type PostgresIndexer struct{}

func New() *PostgresIndexer {
	return &PostgresIndexer{}
}
