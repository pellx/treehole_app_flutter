import { Entity, Column, Index, PrimaryGeneratedColumn, CreateDateColumn, ManyToOne, JoinColumn, Unique } from 'typeorm';
import { UserEntity } from './user.entity';

@Entity('follow_authors')
@Unique('uk_user_author', ['user_token', 'author'])
export class FollowAuthorEntity {
  @PrimaryGeneratedColumn({ type: 'int' })
  id: number;

  @Index('idx_user_token')
  @Column({ type: 'varchar', length: 64, name: 'user_token' })
  user_token: string;

  @Column({ type: 'varchar', length: 100 })
  author: string;

  @CreateDateColumn({ type: 'timestamp', name: 'created_at' })
  created_at: Date;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_token', referencedColumnName: 'internal_token' })
  user: UserEntity;
}
